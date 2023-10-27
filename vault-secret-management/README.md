# Tutorial: Managing Secrets in GCP with Vault

Learn how to manage your secrets in Google Cloud Platform (GCP) using HashiCorp's Vault. This tutorial will guide you through the process of setting up and using the Vault GCP Secrets Engine to generate dynamic service account keys.

## Prerequisites

- Installed and configured Vault
- GCP project setup

## 1. Starting the Vault Server

Before initializing Vault, ensure it's running.

```bash
vault server -config=/etc/vault.d/vault.hcl &
sudo chown -R kimambo:kimambo /opt/vault/data/
export VAULT_ADDR='http://127.0.0.1:8200'
```

## 2. Initialize Vault (First Time Only)

When you run this command for the first time, it will generate unseal keys and a root token.

```bash
vault operator init
```

## 3. Unseal Vault

To unseal Vault, use the following:

```bash
vault operator unseal
```

## 4. Login to Vault

Using the root token provided during the initialization, login to Vault:

```bash
vault login
```

## 5. Enable GCP Secrets Engine

To enable the GCP secrets engine, run:

```bash
vault secrets enable gcp
```

## 6. Configure the GCP Secrets Engine

Set up the secrets engine with the following command:

```bash
vault write gcp/config ttl=120 max_ttl=86400
```

## 7. Create Role Binding Definitions

Define roles for your project. Here's an example binding that allows managing GCE instances and storage buckets:

```hcl
    resource "//cloudresourcemanager.googleapis.com/projects/kimambo-sandbox" {
      roles = [
        "roles/compute.instanceAdmin.v1",
        "roles/iam.serviceAccountUser"  # required if managing instances running as service accounts
      ]
    }
```

> **Note:** You can find more examples in the `role-bindings` folder.

## 8. Define RoleSets

RoleSets associate a set of roles with specific resources in GCP:

```bash
  vault write gcp/roleset/bucket-admin-role \
      project="kimambo-sandbox" \
      secret_type="service_account_key" \
      bindings=@bucket_admin_binding.hcl

  vault write gcp/roleset/project-bucket-admin-role \
      project="kimambo-sandbox" \
      secret_type="service_account_key" \
      bindings=@bucket_admin_project_binding.hcl

  vault write gcp/roleset/compute-instance-admin-role \
      project="kimambo-sandbox" \
      secret_type="service_account_key" \
      bindings=@compute_instance_admin_binding.hcl

  vault write gcp/roleset/compute-instance-admin-gs-role \
      project="kimambo-sandbox" \
      secret_type="service_account_key" \
      bindings=@multiple_roles_binding.hcl

  vault write gcp/roleset/network-admin-role \
      project="kimambo-sandbox" \
      secret_type="service_account_key" \
      bindings=@network_admin_binding.hcl
```

## 9. Dynamically Generate Service Account Keys

Use the following commands to generate service account keys with the necessary permissions:

```bash
  vault read gcp/roleset/bucket-admin-role/key | jq -r .data.private_key | base64 -d > bucket-admin-key.json
  vault read gcp/roleset/project-bucket-admin-role/key | jq -r .data.private_key | base64 -d > project-bucket-admin-key.json
  vault read gcp/roleset/compute-instance-admin-role/key | jq -r .data.private_key | base64 -d > compute-instance-admin-key.json
  vault read gcp/roleset/compute-instance-admin-gs-role/key | jq -r .data.private_key | base64 -d > compute-instance-admin-gs-key.json
  vault read gcp/roleset/network-admin-role/key | jq -r .data.private_key | base64 -d > network-admin-key.json
```

## 10. Setup User Authentication

Enable the `userpass` authentication method and create a user:

```bash
  vault auth enable userpass
  vault write auth/userpass/users/max password=#&l8%UaZBd9hUa8! policies=dev-policy
```

### Set Demo User Credentials

- **Username:** max
- **Password:** your-secret-password

---

Congratulations! You've successfully set up and configured Vault to manage your secrets in GCP.
Ensure to keep your keys and tokens secure and only share them with trusted parties.
