from flask import Flask, request, jsonify
import os
import uuid
import json
import logging
from azure.cosmos import CosmosClient, PartitionKey
from azure.core.exceptions import AzureError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Check for required environment variables
required_env_vars = ["ENDPOINT", "KEY", "DATABASE", "CONTAINER"]
missing_vars = [var for var in required_env_vars if not os.environ.get(var)]

if missing_vars:
    logger.error(f"Missing environment variables: {', '.join(missing_vars)}")
    if os.environ.get("FLASK_ENV") == "production":
        logger.critical("Missing required environment variables in production. Exiting.")
        exit(1)
    ENDPOINT = os.environ.get("ENDPOINT", "")
    KEY = os.environ.get("KEY", "")
    DATABASE = os.environ.get("DATABASE", "")
    CONTAINER = os.environ.get("CONTAINER", "")
    logger.warning("Using empty values for missing environment variables in development")
else:
    ENDPOINT = os.environ["ENDPOINT"]
    KEY = os.environ["KEY"]
    DATABASE = os.environ["DATABASE"]
    CONTAINER = os.environ["CONTAINER"]

# Function to connect to Cosmos DB
def connect_to_cosmos_db(endpoint, key, database_name, container_name):
    try:
        cosmos_client = CosmosClient(url=endpoint, credential=key)
        db_client = cosmos_client.create_database_if_not_exists(id=database_name)
        container_client = db_client.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/id"),
            offer_throughput=400
        )
        logger.info(f"Successfully connected to Cosmos DB: {database_name}/{container_name}")
        return cosmos_client, db_client, container_client, None
    except Exception as e:
        error_msg = f"Failed to connect to Cosmos DB: {str(e)}"
        logger.error(error_msg)
        return None, None, None, error_msg

# Connect to Cosmos DB
client, database, container, cosmos_error = connect_to_cosmos_db(ENDPOINT, KEY, DATABASE, CONTAINER)
if cosmos_error:
    logger.error(f"Application will continue but Cosmos DB operations may fail: {cosmos_error}")

def load_data_from_json():
    try:
        with open('data.json', 'r') as file:
            data = json.load(file)
        return data
    except FileNotFoundError:
        logger.warning("data.json file not found")
        return []
    except json.JSONDecodeError:
        logger.error("Invalid JSON in data.json")
        return []

# Load initial data only if we're not in production
if os.environ.get("FLASK_ENV") != "production" and container:
    data = load_data_from_json()
    for item in data:
        try:
            container.create_item(body=item)
            logger.info(f"Item {item['id']} successfully added.")
        except Exception as e:
            logger.error(f"Error adding item {item['id']}: {str(e)}")

@app.route('/')
def home():
    return "Hello, this is the code assignment app."

@app.route('/data', methods=['POST'])
def add_data():
    logger.info("POST /data route accessed")
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        data["id"] = str(uuid.uuid4())
        container.create_item(body=data)
        return jsonify({"status": "success", "id": data["id"]}), 201
    except Exception as e:
        logger.error(f"Error in POST /data: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/data', methods=['GET'])
def get_data():
    logger.info("GET /data route accessed")
    try:
        if container is None:
            raise ValueError("Cosmos DB container is not initialized.")
        # Get data from Cosmos DB
        items = list(container.read_all_items(max_item_count=100))
        return jsonify(items)
    except Exception as e:
        logger.error(f"Error in GET /data: {str(e)}")
        return jsonify({"error": f"Failed to retrieve data from Cosmos DB: {str(e)}"}), 500

@app.route('/datalocal', methods=['GET'])
def get_local_data():
    logger.info("GET /datalocal route accessed")
    try:
        # Read from data.json
        items = load_data_from_json()
        return jsonify(items)
    except Exception as e:
        logger.error(f"Error in GET /datalocal: {str(e)}")
        return jsonify({"error": f"Failed to retrieve data from local file: {str(e)}"}), 500

if __name__ == '__main__':
    # Use port 5000 for local development, port 80 for production
    port = int(os.environ.get("PORT", 80))
    app.run(host='0.0.0.0', port=port, debug=os.environ.get("FLASK_ENV") == "development")
