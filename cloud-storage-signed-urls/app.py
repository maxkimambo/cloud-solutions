# Generate http endpoint, that will get url as a parameter and return signed url

from datetime import timedelta
from flask import Flask, request, jsonify, render_template
from google.cloud import storage

from google.oauth2 import service_account
import logging


formatter = logging.Formatter(
    fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
handler = logging.StreamHandler()
handler.setFormatter(formatter)

logger = logging.getLogger(__name__)
log = logging.getLogger()

app = Flask(__name__)


@app.route('/sign', methods=["POST"])
def sign_url():
    """Generate signed URL for blob."""
    try:
        log.info(f"Request received: {request.get_json()}")
        data = request.get_json()
        bucket_name = data.get('bucket_name')
        blob_name = data.get('blob_name', {}).get('resolved', {})
        # default 1 hour customize as per your requirements.
        expiration_delta = data.get('expiration', 3600)
        expiration = timedelta(seconds=expiration_delta)
        sa = "/app/sa.json"

        ALLOWED_METHOD = 'GET'
        credentials = service_account.Credentials.from_service_account_file(
            sa)
        storage_client = storage.Client(credentials=credentials)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        url = blob.generate_signed_url(
            expiration=expiration, method=ALLOWED_METHOD)
        res = {"url": url}
        log.info(f"Signed URL: {url}")
        return jsonify(res)

    except Exception as e:
        return f"Error: {e}"


@app.route('/', methods=["GET"])
def index():

    return render_template('index.html')


if __name__ == '__main__':
    PORT = 8080
    log.info(f"Starting Flask server on port : {PORT}...")
    app.run(host="0.0.0.0", port=PORT, debug=True)
    log.info("Flask server started!")
