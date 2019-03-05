import json, os, requests, urllib
from flask import Flask, render_template, request, redirect, flash, url_for

app = Flask(__name__)
app.secret_key = os.urandom(32)

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/search", methods=["GET"])
def search():
    if (request.args):
        args = request.args
        locationName = args["name"]

        key = ''
        with open('GOOGLE_MAPS_API_KEY', 'rU') as key_file:
            key = key_file.read().strip()

        results = {[]}
        return render_template("search.html", results = results)


    else:
        return render_template("search.html")










@app.route("/directions")
def directions():

    # INSERT API KEY HERE
    key = ''
    with open('GOOGLE_MAPS_API_KEY', 'rU') as key_file:
        key = key_file.read().strip()

    return render_template("directions.html")





#------- run ----------
if __name__ == "__main__":
    app.debug = True
    app.run()
