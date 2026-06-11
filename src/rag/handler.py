"""
Lambda handler for RAG-based natural language queries over analytics data.
Uses Bedrock Knowledge Bases to retrieve context and generate answers.
"""
import json
import os

import boto3

bedrock_agent = boto3.client("bedrock-agent-runtime")
KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
MODEL_ARN = os.environ.get("MODEL_ARN", "arn:aws:bedrock:ap-south-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0")


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        query = body.get("question", "")

        if not query:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing 'question' field"}),
            }

        # Query Bedrock Knowledge Base (RAG)
        response = bedrock_agent.retrieve_and_generate(
            input={"text": query},
            retrieveAndGenerateConfiguration={
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": {
                    "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                    "modelArn": MODEL_ARN,
                },
            },
        )

        answer = response["output"]["text"]
        citations = [
            {
                "content": c["retrievedReferences"][0]["content"]["text"]
                if c.get("retrievedReferences") else None
            }
            for c in response.get("citations", [])
        ]

        return {
            "statusCode": 200,
            "body": json.dumps({
                "answer": answer,
                "citations": citations,
            }),
        }

    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Failed to process query"}),
        }
