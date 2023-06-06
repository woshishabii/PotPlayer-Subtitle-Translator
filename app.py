import urllib.parse

from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, pipeline

translation_en_zh_opus = pipeline("translation_en_to_zh",
                                  model=AutoModelForSeq2SeqLM.from_pretrained('Helsinki-NLP/opus-mt-en-zh'),
                                  tokenizer=AutoTokenizer.from_pretrained('Helsinki-NLP/opus-mt-en-zh'))

from flask import Flask, jsonify
from markupsafe import escape

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
app.config['JSONIFY_MIMETYPE'] = "application/json;charset=utf-8"

@app.route("/")
def ping():
    return "Pong!"


@app.route("/translate/<content>")
def translate(content):
    try:
        return jsonify({
            'Status': '200',
            'Input': urllib.parse.unquote(escape(content)),
            'Result': [{'dst': translation_en_zh_opus(urllib.parse.unquote(escape(content)))[0]['translation_text']}],
        })
    except KeyError:
        return jsonify({
            'Status': '500',
            'Message': 'Can\'t be translated',
        })
