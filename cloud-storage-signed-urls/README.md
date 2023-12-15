## Build the container image 

```bash
    docker build -t cloud-storage-signed-urls .
```
Push it to a container registry of your choice.

You will need to run this container and give it access to the service account key file, 
that will be used to sign the urls.

The endpoint for signing urls is /sign and it accepts a json payload with the following structure:

```json
{
    "bucket_name": "bucket_name",
    "blob_name": "blob_name",
    "expiration": 3600
}
```
Adjust this to your needs.

## Dialogflow fulfillment

This endpoint needs to be configured as a webhook in dialogflow fulfillment.
Passing the parameters as a json payload.
The parameters will be extracted from the users intent in during the chat session with the user. 

See the exported_agent_DownloadBot folder for an example of how to configure the intent and the fulfillment. 

To extract the parameters from the intent, you will need to create a custom entity in dialogflow.
and annotate training phrases with the entity.

See: 
- https://cloud.google.com/dialogflow/cx/docs/concept/intent#annot
- https://cloud.google.com/dialogflow/cx/docs/concept/parameter
- 

To reference the parameters in the payload, you will need to use the following format.

For intent params:

$intent.params.parameter-id.original
$intent.params.parameter-id.resolved

For session params

$session.params.parameter-id.original
$session.params.parameter-id.resolved


## Webhook response 

The webhook will respond with 

{
    "url": "url"
}

Parse this response back into the session.params by referencing it as $.url. 

Then you can use it in the chat session to return a custom payload to the user.

# Starting the application locally

python app.py

## Generate a signed url from the command line

```bash
    curl -X POST http://service_host:8080/sign -H "Content-Type:application/json" -d '{ "bucket_name":"kimambo-cloud-store-chat-bot", "blob_name":"document.pdf" }'
```

Call this endpoint using dialogflow fulfillment webhook.
Then retunr the url to the user or redirect the user server side to the signed url.

## Generate a signed url with a custom expiration time

```bash
    curl -X POST http://service_host:8080/sign -H "Content-Type:application/json" -d '{ "bucket_name":"kimambo-cloud-store-chat-bot", "blob_name":"python-cookbook.pdf", "expiration": 3600 }'
```