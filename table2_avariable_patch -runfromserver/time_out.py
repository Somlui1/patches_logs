import asyncio
import aiohttp
import base64
import time
from typing import Dict, Any, List

# =========================
# 🔐 TENANTS
# =========================
TENANTS = {
    "ah": {
        "credential": "583db905e5af13cd_r_id:it@minAPI1WGant!",
        "api_key": "FfSghSoNzPlloALCK9LN5E46rzGnAYqxJ+mgirtf",
        "account": "WGC-3-981e96282dcc4ad0856c",
    }
}

BASE_URL = "https://api.jpn.cloud.watchguard.com"
TOKEN_URL = f"{BASE_URL}/oauth/token"

# =========================
# ⏱ Timer helper
# =========================
def now():
    return time.perf_counter()

# =========================
# 🔑 Get OAuth Token (ONCE)
# =========================
async def get_token(session: aiohttp.ClientSession, credential: str) -> str:
    cred_b64 = base64.b64encode(credential.encode()).decode()

    headers = {
        "Accept": "application/json",
        "Authorization": f"Basic {cred_b64}",
        "Content-Type": "application/x-www-form-urlencoded",
    }

    data = {
        "grant_type": "client_credentials",
        "scope": "api-access",
    }

    async with session.post(TOKEN_URL, headers=headers, data=data) as resp:
        resp.raise_for_status()
        js = await resp.json()

    token = js.get("access_token")
    if not token:
        raise RuntimeError("Token is null")

    return token

# =========================
# 🌐 Fetch Devices
# =========================
async def fetch_devices(
    session: aiohttp.ClientSession,
    tenant: dict,
    token: str,
    segment: str,
    retrieve: str,
    query: str,
    sem: asyncio.Semaphore,
) -> Dict[str, Any]:

    async with sem:
        url = (
            f"{BASE_URL}/rest/{segment}/management/api/v1/"
            f"accounts/{tenant['account']}/{retrieve}?{query}"
        )

        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "WatchGuard-API-Key": tenant["api_key"],
            "Authorization": f"Bearer {token}",
        }

        async with session.get(url, headers=headers) as resp:
            resp.raise_for_status()
            return await resp.json()

# =========================
# 🔁 Adaptive Page Fetch
# =========================
async def fetch_with_fallback(
    session,
    tenant,
    token,
    segment,
    retrieve,
    skip,
    sem,
):
    for top in (2000, 1500, 1200, 800):
        try:
            query = f"$top={top}&$skip={skip}"
            return await fetch_devices(
                session,
                tenant,
                token,
                segment,
                retrieve,
                query,
                sem,
            )
        except asyncio.TimeoutError:
            print(f"⚠️ timeout at skip={skip}, top={top}, retry smaller")

    raise RuntimeError(f"❌ All page sizes failed at skip={skip}")

# =========================
# 🚀 MAIN (TEST)
# =========================
async def main():
    t_start = now()

    segment = "endpoint-security"
    retrieve = "patchavailability"

    # ⭐ tuning point
    max_concurrent = 6

    timeout = aiohttp.ClientTimeout(
        total=90,
        connect=10,
        sock_read=60,
    )

    sem = asyncio.Semaphore(max_concurrent)
    patches: List[dict] = []

    async with aiohttp.ClientSession(timeout=timeout) as session:

        # 🔑 TOKEN
        t0 = now()
        token = await get_token(session, TENANTS["ah"]["credential"])
        t1 = now()
        print(f"🔑 Token acquired in {t1 - t0:.2f}s")

        # 🔹 FIRST PAGE (to get total)
        t2 = now()
        first = await fetch_devices(
            session,
            TENANTS["ah"],
            token,
            segment,
            retrieve,
            "$top=1200&$skip=0&$count=true",
            sem,
        )
        t3 = now()

        total = first["total_items"]
        patches.extend(first["data"])

        print(f"Fetched first page: {len(first['data'])}/{total}")
        print(f"⏱ First page time: {t3 - t2:.2f}s")

        # 🔹 PAGINATION
        skips = list(range(1200, total, 1200))
        tasks = [
            fetch_with_fallback(
                session,
                TENANTS["ah"],
                token,
                segment,
                retrieve,
                skip,
                sem,
            )
            for skip in skips
        ]

        completed = 0
        t4 = now()

        for coro in asyncio.as_completed(tasks):
            result = await coro
            patches.extend(result.get("data", []))
            completed += 1

            print(
                f"Progress {completed}/{len(tasks)} "
                f"→ {len(patches)}/{total}"
            )

        t5 = now()

    print("\n==========================")
    print(f"⏱ Token time       : {t1 - t0:.2f}s")
    print(f"⏱ First page time  : {t3 - t2:.2f}s")
    print(f"⏱ Async fetch time : {t5 - t4:.2f}s")
    print(f"⏱ Total time       : {t5 - t_start:.2f}s")
    print(f"✔ Total patches    : {len(patches)}")

# =========================
# ▶ RUN
# =========================
if __name__ == "__main__":
    asyncio.run(main())
