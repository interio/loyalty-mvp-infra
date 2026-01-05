#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

BACKEND_URL="${BACKEND_URL:-${API_BASE_URL:-http://localhost:8080}}"

python3 - <<'PY'
import json, os, sys, uuid, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

backend = os.environ.get("BACKEND_URL", "http://localhost:8080").rstrip("/")

def post_json(path: str, payload: dict, expect_graphql: bool = False):
    url = f"{backend}{path}"
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = resp.read()
            parsed = json.loads(data.decode())
            if expect_graphql:
                if "errors" in parsed:
                    raise RuntimeError(f"GraphQL error: {parsed['errors']}")
                return parsed["data"]
            return parsed
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        raise SystemExit(f"HTTP {e.code} for {path}: {detail}")
    except urllib.error.URLError as e:
        raise SystemExit(f"Cannot reach backend at {backend}: {e}")

def graphql(query: str, variables: dict):
    payload = {"query": query, "variables": variables}
    return post_json("/graphql", payload, expect_graphql=True)

def main():
    print(f"Using backend: {backend}")

    # 1) Tenant
    tenant_name = "Heineken Demo Tenant"
    t_res = graphql(
        """
        mutation CreateTenant($input: CreateTenantInput!) {
          createTenant(input: $input) { id name }
        }
        """,
        {"input": {"name": tenant_name}},
    )
    tenant = t_res["createTenant"]
    tenant_id = tenant["id"]
    print(f"Tenant: {tenant_name} -> {tenant_id}")

    # 2) Customer
    customer_input = {
        "tenantId": tenant_id,
        "name": "Green Bar & Grill",
        "contactEmail": "contact@greenbar.test",
        "externalId": "CUST-HEI-001",
    }
    c_res = graphql(
        """
        mutation CreateCustomer($input: CreateCustomerInput!) {
          createCustomer(input: $input) { id name tenantId externalId }
        }
        """,
        {"input": customer_input},
    )
    customer = c_res["createCustomer"]
    customer_id = customer["id"]
    print(f"Customer: {customer['name']} -> {customer_id}")

    # 3) Users
    users = [
        {"email": "admin@greenbar.test", "role": "administrator", "externalId": "USR-ADMIN-001"},
        {"email": "owner@greenbar.test", "role": "owner", "externalId": "USR-OWNER-001"},
    ]
    created_users = []
    for u in users:
        u_res = graphql(
            """
            mutation CreateUser($input: CreateUserInput!) {
              createUser(input: $input) { id email role customerId }
            }
            """,
            {"input": {"tenantId": tenant_id, "customerId": customer_id, **u}},
        )
        created = u_res["createUser"]
        created_users.append(created)
        print(f"User: {created['email']} -> {created['id']} ({created['role']})")

    admin_id = created_users[0]["id"]
    owner_id = created_users[1]["id"]

    # 4) Ledger transactions (manual adjustments + redemption)
    adj = lambda amount, actor: graphql(
        """
        mutation ManualAdjust($input: ManualAdjustPointsInput!) {
          manualAdjustPoints(input: $input) { balance }
        }
        """,
        {"input": {"customerId": customer_id, "actorUserId": actor, "amount": amount, "correlationId": str(uuid.uuid4())}},
    )
    red = lambda amount, actor: graphql(
        """
        mutation Redeem($input: RedeemPointsInput!) {
          redeemPoints(input: $input) { balance }
        }
        """,
        {"input": {"customerId": customer_id, "actorUserId": actor, "amount": amount, "reason": "reward_redeem", "correlationId": str(uuid.uuid4())}},
    )

    adj(500, admin_id)
    adj(200, admin_id)
    adj(150, owner_id)
    red(120, owner_id)
    red(80, owner_id)
    print("Ledger seeded with manual adjustments and redemptions.")

    # 5) Products (10 SKUs)
    products = [
        {"distributorId": tenant_id, "sku": "BEER-HEINEKEN-BTL-24PK", "name": "Heineken Bottle 24pk", "gtin": "000123456001", "cost": 38.50, "attributes": {"category": "beer", "package": "bottle", "size": "24pk"}},
        {"distributorId": tenant_id, "sku": "BEER-HEINEKEN-KEG-50L", "name": "Heineken Keg 50L", "gtin": "000123456002", "cost": 210.00, "attributes": {"category": "beer", "package": "keg", "size": "50l"}},
        {"distributorId": tenant_id, "sku": "BEER-HEINEKEN-DRAUGHT-30L", "name": "Heineken Draught 30L", "gtin": "000123456003", "cost": 145.00, "attributes": {"category": "beer", "package": "keg", "size": "30l"}},
        {"distributorId": tenant_id, "sku": "BEER-HEINEKEN-BTL-12PK", "name": "Heineken Bottle 12pk", "gtin": "000123456004", "cost": 20.00, "attributes": {"category": "beer", "package": "bottle", "size": "12pk"}},
        {"distributorId": tenant_id, "sku": "BEER-AMSTEL-BTL-24PK", "name": "Amstel Bottle 24pk", "gtin": "000123456005", "cost": 34.00, "attributes": {"category": "beer", "package": "bottle", "size": "24pk"}},
        {"distributorId": tenant_id, "sku": "BEER-AMSTEL-KEG-50L", "name": "Amstel Keg 50L", "gtin": "000123456006", "cost": 195.00, "attributes": {"category": "beer", "package": "keg", "size": "50l"}},
        {"distributorId": tenant_id, "sku": "CIDER-STRONGBOW-KEG-50L", "name": "Strongbow Cider Keg 50L", "gtin": "000123456007", "cost": 185.00, "attributes": {"category": "cider", "package": "keg", "size": "50l"}},
        {"distributorId": tenant_id, "sku": "CIDER-STRONGBOW-BTL-24PK", "name": "Strongbow Cider Bottle 24pk", "gtin": "000123456008", "cost": 33.00, "attributes": {"category": "cider", "package": "bottle", "size": "24pk"}},
        {"distributorId": tenant_id, "sku": "BEER-NEWCASTLE-BTL-24PK", "name": "Newcastle Brown Ale Bottle 24pk", "gtin": "000123456009", "cost": 36.00, "attributes": {"category": "beer", "package": "bottle", "size": "24pk"}},
        {"distributorId": tenant_id, "sku": "BEER-REDSTRIPE-BTL-24PK", "name": "Red Stripe Bottle 24pk", "gtin": "000123456010", "cost": 35.00, "attributes": {"category": "beer", "package": "bottle", "size": "24pk"}},
    ]
    post_json("/api/v1/products/upsert", {"products": products})
    print("Products inserted (10 items).")

    # 6) Invoices (several, using external customer id + actor email)
    invoices = [
        {
            "invoiceId": "INV-1001",
            "occurredAt": (datetime.now(timezone.utc) - timedelta(days=7)).isoformat(),
            "customerExternalId": customer_input["externalId"],
            "currency": "EUR",
            "actorEmail": users[0]["email"],
            "lines": [
                {"sku": "BEER-HEINEKEN-BTL-24PK", "quantity": 6, "netAmount": 225.00},
                {"sku": "BEER-HEINEKEN-KEG-50L", "quantity": 1, "netAmount": 210.00},
            ],
        },
        {
            "invoiceId": "INV-1002",
            "occurredAt": (datetime.now(timezone.utc) - timedelta(days=3)).isoformat(),
            "customerExternalId": customer_input["externalId"],
            "currency": "EUR",
            "actorEmail": users[1]["email"],
            "lines": [
                {"sku": "BEER-AMSTEL-BTL-24PK", "quantity": 4, "netAmount": 136.00},
                {"sku": "CIDER-STRONGBOW-KEG-50L", "quantity": 1, "netAmount": 185.00},
            ],
        },
        {
            "invoiceId": "INV-1003",
            "occurredAt": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat(),
            "customerExternalId": customer_input["externalId"],
            "currency": "EUR",
            "actorEmail": users[1]["email"],
            "lines": [
                {"sku": "BEER-HEINEKEN-DRAUGHT-30L", "quantity": 1, "netAmount": 145.00},
                {"sku": "BEER-HEINEKEN-BTL-12PK", "quantity": 3, "netAmount": 60.00},
                {"sku": "BEER-REDSTRIPE-BTL-24PK", "quantity": 2, "netAmount": 70.00},
            ],
        },
    ]

    for inv in invoices:
        payload = {
            "tenantId": tenant_id,
            **inv,
        }
        res = post_json("/api/v1/integration/invoices/apply", payload)
        corr = res.get("correlationId", inv["invoiceId"])
        print(f"Invoice {inv['invoiceId']} accepted (correlation {corr}).")

    print("Seeding completed.")

if __name__ == "__main__":
    main()
PY
