import asyncio
import aiohttp
import base64
import time
from typing import Dict, Any, List

TENANTS = {
    "ah": {
        "credential": "583db905e5af13cd_r_id:it@minAPI1WGant!",
        "api_key": "FfSghSoNzPlloALCK9LN5E46rzGnAYqxJ+mgirtf",
        "account": "WGC-3-981e96282dcc4ad0856c",
    }
}
BASE_URL = "https://api.jpn.cloud.watchguard.com"
TOKEN_URL = f"{BASE_URL}/oauth/token"

def now():
    return time.perf_counter()
# =========================
# 🔑 Token (once)
# =========================
async def get_token(session, credential: str) -> str:
    cred_b64 = base64.b64encode(credential.encode()).decode()
    async with session.post(
        TOKEN_URL,
        headers={
            "Authorization": f"Basic {cred_b64}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "client_credentials", "scope": "api-access"},
        timeout=60,
    ) as resp:
        resp.raise_for_status()
        return (await resp.json())["access_token"]

# =========================
# 🌐 Fetch with retry
# =========================
async def fetch_devices(
    session,
    tenant,
    token,
    segment,
    retrieve,
    query,
    sem,
    retries=2,
):
    url = (
        f"{BASE_URL}/rest/{segment}/management/api/v1/"
        f"accounts/{tenant['account']}/{retrieve}?{query}"
    )
    headers = {
        "WatchGuard-API-Key": tenant["api_key"],
        "Authorization": f"Bearer {token}",
    }

    async with sem:
        for attempt in range(1, retries + 2):
            try:
                async with session.get(url, headers=headers) as resp:
                    resp.raise_for_status()
                    return await resp.json()
            except asyncio.TimeoutError:
                if attempt > retries:
                    raise
                print(f"⚠️ timeout retry {attempt} → {query}")

# =========================
# 🚀 Main
# =========================

async def main():
    t_start = now()
    segment = "endpoint-security"
    retrieve = "patchavailability"
    top = 1500
    max_concurrent = 8

    sem = asyncio.Semaphore(max_concurrent)
    patches: List[dict] = []

    timeout = aiohttp.ClientTimeout(total=300)
    connector = aiohttp.TCPConnector(limit=20, limit_per_host=10)

    async with aiohttp.ClientSession(
        timeout=timeout, connector=connector
    ) as session:

        token = await get_token(session, TENANTS["ah"]["credential"])

        # 🔹 First page
        first = await fetch_devices(
            session,
            TENANTS["ah"],
            token,
            segment,
            retrieve,
            f"$top={top}&$skip=0&$count=true",
            sem,
        )

        total = first["total_items"]
        patches.extend(first["data"])

        print(f"Fetched first page: {len(first['data'])}/{total}")

        skips = list(range(top, total, top))

        tasks = [
            fetch_devices(
                session,
                TENANTS["ah"],
                token,
                segment,
                retrieve,
                f"$top={top}&$skip={skip}",
                sem,
            )
            for skip in skips
        ]

        completed = 0
        for coro in asyncio.as_completed(tasks):
            result = await coro
            patches.extend(result.get("data", []))
            completed += 1
            print(f"Progress {completed}/{len(tasks)} → {len(patches)}/{total}")

    print("\n==========================")
    print(f"⏱ Total time : {now() - t_start:.2f}s")
    print(f"✔ Total patches: {len(patches)}")

if __name__ == "__main__":
    asyncio.run(main())
