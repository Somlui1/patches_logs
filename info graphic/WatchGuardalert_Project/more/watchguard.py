
from typing import List, Dict, Any
import base64
import requests
from urllib.parse import urlencode
from collections import defaultdict
import csv
from fastapi.responses import StreamingResponse
TENANTS = {
    "ah": {
        "Credential": "583db905e5af13cd_r_id:it@minAPI1WGant!",
        "APIKey": "FfSghSoNzPlloALCK9LN5E46rzGnAYqxJ+mgirtf",
        "Account": "WGC-3-981e96282dcc4ad0856c"
    },
    "as": {
        "Credential": "8f6543f42f463fc6_r_id:5QG+M=H+)3iL)Fw",
        "APIKey": "yujbaVOGmOi5rzxU2wBwcCJMLrkKyxU7Fbw8rQgj",
        "Account": "WGC-3-50b8aa46e31d448698c7"
    },
    "ar": {
        "Credential": "7be27fa3e7cc352a_r_id:^^K7Uc~7PYruSek",
        "APIKey": "66eMRiegSh7EhWQh6C9S5hAnQ75OScy6T9kx+VKo",
        "Account": "WGC-3-048294f7f1ed497981c8"
    }
}

def fetch_devices(tenant_name: str, segment: str, retrive: str, querystring: str | None = None):

    results = defaultdict(list)  # สำหรับเก็บข้อมูลรวมตาม key
    errors = {}

    # ---------------------------
    # 1) เตรียม TENANTS_KEYS
    # ---------------------------
    if tenant_name.lower() == 'all':
        TENANTS_KEYS = list(TENANTS.keys())
    elif tenant_name not in TENANTS:
        return {}, {tenant_name: "Tenant does not exist."}
    else:
        TENANTS_KEYS = [tenant_name]

    # ---------------------------
    # 2) Loop ทุก tenant
    # ---------------------------
    for key in TENANTS_KEYS:
        tenant = TENANTS[key]

        try:
            # --------------------- GET TOKEN ---------------------
            cred_b64 = base64.b64encode(tenant["Credential"].encode()).decode()
            token_resp = requests.post(
                "https://api.jpn.cloud.watchguard.com/oauth/token",
                headers={
                    "accept": "application/json",
                    "Authorization": f"Basic {cred_b64}",
                    "Content-Type": "application/x-www-form-urlencoded"
                },
                data={"grant_type": "client_credentials", "scope": "api-access"}
            )
            token_resp.raise_for_status()
            token = token_resp.json().get("access_token")
            if not token:
                raise Exception("Token is null")

            # --------------------- GET DEVICES ---------------------
            url = f"https://api.jpn.cloud.watchguard.com/rest/{segment}/management/api/v1/accounts/{tenant['Account']}/{retrive}?{querystring}"
            dev_resp = requests.get(
                url,
                headers={
                    "accept": "application/json",
                    "Content-Type": "application/json",
                    "WatchGuard-API-Key": tenant["APIKey"],
                    "Authorization": f"Bearer {token}"
                },
                timeout=120
            )

            data = dev_resp.json()

            # --------------------- MERGE DATA ---------------------
            for k, v in data.items():
                if isinstance(v, list):
                    results[k].extend(v)   # ถ้าเป็น list → extend
                else:
                    results[k].append(v)   # ถ้าเป็นค่าเดี่ยว → append

        except Exception as e:
            errors[key] = str(e)

    # ---------------------------
    # 3) Return
    # ---------------------------
    return dict(results), errors


