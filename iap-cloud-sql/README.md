# Connecting to a Private Cloud SQL Instance

This guide details the steps required to establish a connection to a private Cloud SQL instance from a local machine, which is essential for development or administrative tasks.

## Pre-requisites

Before you proceed, ensure the following:

- A Cloud NAT is set up in the VPC, enabling the bastion host's internet access.
- Your local machine has the subsequent tools installed:
  - Terraform
  - gcloud
  - mysql client
- Adequate roles and permissions to create the required resources.
- A role to access the Cloud SQL instance, specifically the `cloudsql.instances.connect` role.

## Architecture Overview

Utilizing the terraform code from this repository will facilitate the creation of:

- A VPC network.
- A subnet.
- A Cloud SQL instance using a private IP.
- A bastion host with a private IP.
- Firewall rules permitting SSH and mysql client access through Identity Aware Proxy (IAP).
- VPC peering between the 'ard-demo' VPC and the CloudSQL Google-managed VPC.

This represents a typical setup for accessing CloudSQL. In this configuration, the SQL server becomes accessible to all hosts within the VPC.

## Setup Procedure

1. **Clone the Repository**

    ```bash
    git clone [repository-link]
    ```

2. **Initialize Terraform Providers**

    ```bash
    terraform init --upgrade
    ```

3. **Authenticate with gcloud**

    You can either:

    ```bash
    gcloud auth application-default login
    ```
    
    Or set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to direct it to a specific service account key file.

4. **Resource Creation**

    ```bash
    terraform apply
    ```

    Post successful application, you can view the created resources within the GCP console:

    - Cloud SQL Instance: ![Sql](image.png)
    - Private Bastion Host: ![Bastion](image-1.png)
    - Identity Aware Proxy: ![IAP](image-3.png)

5. **Bastion Host Access**

    To connect to a bastion host without an external IP, traffic should be tunneled via IAP:

    ```bash
    gcloud compute ssh bastion --zone=europe-west3-a --tunnel-through-iap
    ```

6. **Retrieve Cloud SQL Instance Info**

    List instances:

    ```bash
    gcloud sql instances list
    ```

    To obtain connection details:

    ```bash
    gcloud sql instances describe ard-demo-d051 --format="value(connectionName)"
    ```

    You should receive a result similar to: `kimambo-sandbox:europe-west3:ard-demo-d051`

7. **Activate Cloud SQL Proxy**

    ```bash
    cloud_sql_proxy -instances=ard-demo:europe-west3:ard-demo-mysql
    ```

    At this juncture, the bastion host is prepped to accept and forward connections to the Cloud SQL instance. Validate the connection:

    ```bash
    mysql -h127.0.0.1 --port3306 -u root -p
    ```

    If successful, you're set to connect via your local machine.

8. **Local Machine Connection**

    Utilize the IAP's tunneling capabilities:

    ```bash
    gcloud compute start-iap-tunnel bastion 3306 --local-host-port=localhost:3306 --zone=europe-west3-a
    ```

    This command establishes a tunnel between your local machine and the bastion host. Subsequently, you can connect to the Cloud SQL instance:

    ```bash
    mysql -h127.0.0.1 --port3306 -u root -p
    ```

    Note: IAP disconnects after 1-hour of inactivity. Ensure your applications are equipped to reinitiate tunnels when needed. For this demonstration, we used Beekeeper Studio as GUI client to connect from local machine to CloudSQL:

    ![Beekeeper](image-2.png)

## Benefits:

- IP address whitelisting isn't required.
- Avoids VPN connections.
- Eliminates the need for an external IP bastion host.
- The cloud sql proxy remains active on the bastion host, allowing users to create tunnels when granted access to the IAP destination.

## Limitations:

- Due to IAP's 1-hour inactivity session timeout, ensure mechanisms are in place to manage tunnel reconnections.
- This method isn't suited for extensive data transfers, making it inappropriate for data migration tasks.

## Additional Resources:

- [Connecting to Cloud SQL with Private IP](https://cloud.google.com/sql/docs/mysql/connect-instance-private-ip)
- [Using the Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/mysql/connect-auth-proxy)
- [Using TCP Forwarding with IAP](https://cloud.google.com/iap/docs/using-tcp-forwarding)