#!/usr/bin/env python3
import urllib.request
import json
import sys

PROD_PROJECT = "xloop-tours-invoice"
DEV_PROJECT = "xloop-tours-dev"

COLLECTIONS = [
    "Settings",
    "allowed_users",
    "companies",
    "counters",
    "customers",
    "employees",
    "invoices",
    "maintenance_types",
    "notifications",
    "settings",
    "travelers",
    "vat_filings",
    "vehicle_makes",
    "vehicles",
    "xloop_company"
]

def make_request(url, method="GET", data=None):
    req = urllib.request.Request(url, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
        json_data = json.dumps(data).encode("utf-8")
    else:
        json_data = None
    
    try:
        with urllib.request.urlopen(req, data=json_data) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_content = e.read().decode("utf-8")
        print(f"HTTP Error {e.code} on {method} {url}: {err_content}")
        raise e

def fetch_all_documents(project_id, collection_id):
    docs = []
    page_token = None
    
    while True:
        url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_id}?pageSize=300"
        if page_token:
            url += f"&pageToken={page_token}"
            
        try:
            res = make_request(url)
            page_docs = res.get("documents", [])
            docs.extend(page_docs)
            
            page_token = res.get("nextPageToken")
            if not page_token:
                break
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Collection might not exist or be empty
                break
            raise e
            
    return docs

def commit_batch(project_id, writes):
    if not writes:
        return
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:commit"
    make_request(url, method="POST", data={"writes": writes})

def main():
    print("=" * 60)
    print(f"Firestore Sync: {PROD_PROJECT} (PROD) -> {DEV_PROJECT} (DEV)")
    print("=" * 60)
    
    confirm = input("This will overwrite all data in the DEV database. Are you sure? (yes/no): ")
    if confirm.lower() != "yes":
        print("Sync cancelled.")
        return

    for col in COLLECTIONS:
        print(f"\nProcessing collection: '{col}'")
        
        # 1. Fetch existing dev docs to delete
        print("  Retrieving existing DEV documents...")
        try:
            dev_docs = fetch_all_documents(DEV_PROJECT, col)
        except Exception as e:
            print(f"  Error retrieving DEV documents: {e}")
            continue
        
        if dev_docs:
            print(f"  Found {len(dev_docs)} documents in DEV. Deleting them...")
            delete_writes = []
            for doc in dev_docs:
                delete_writes.append({"delete": doc["name"]})
                
                # Commit in batches of 200
                if len(delete_writes) == 200:
                    try:
                        commit_batch(DEV_PROJECT, delete_writes)
                    except Exception as e:
                        print(f"  Error committing delete batch: {e}")
                    delete_writes = []
            
            if delete_writes:
                try:
                    commit_batch(DEV_PROJECT, delete_writes)
                except Exception as e:
                    print(f"  Error committing delete batch: {e}")
            print("  DEV documents deleted.")
        else:
            print("  No existing documents found in DEV.")
            
        # 2. Fetch prod docs to copy
        print("  Retrieving PROD documents...")
        try:
            prod_docs = fetch_all_documents(PROD_PROJECT, col)
        except Exception as e:
            print(f"  Error retrieving PROD documents: {e}")
            continue
        
        if prod_docs:
            print(f"  Found {len(prod_docs)} documents in PROD. Copying to DEV...")
            update_writes = []
            for doc in prod_docs:
                # Map prod document name to dev document name
                prod_name = doc["name"]
                dev_name = prod_name.replace(f"projects/{PROD_PROJECT}", f"projects/{DEV_PROJECT}")
                
                update_writes.append({
                    "update": {
                        "name": dev_name,
                        "fields": doc.get("fields", {})
                    }
                })
                
                # Commit in batches of 200
                if len(update_writes) == 200:
                    try:
                        commit_batch(DEV_PROJECT, update_writes)
                    except Exception as e:
                        print(f"  Error committing update batch: {e}")
                    update_writes = []
                    
            if update_writes:
                try:
                    commit_batch(DEV_PROJECT, update_writes)
                except Exception as e:
                    print(f"  Error committing update batch: {e}")
            print(f"  Successfully copied {len(prod_docs)} documents.")
        else:
            print("  No documents found in PROD to copy.")
            
    print("\n" + "=" * 60)
    print("Firestore database synchronization completed successfully!")
    print("=" * 60)

if __name__ == "__main__":
    main()
