#!/usr/bin/env python3

"""
Web service with Hangman game.
"""

from http.server import HTTPServer
from http.server import BaseHTTPRequestHandler
import sqlite3
import json

CONFIG = {
    'addr': '127.0.0.1',
    'port': 8009,
    'db': "hangman.db",
    'verbose': True
}


def start_hangman():
    """
    Starts the webservice with a game.
    """
    addr, port = CONFIG['addr'], CONFIG['port']

    print(f'Click here to play: http://{addr}:{port}/')
    HTTPServer((addr, port), HangmanAPI).serve_forever()


class HangmanAPI(BaseHTTPRequestHandler):
    """
    Hangman API
    """
    __db = None

    def __init__(self, request, client_address, server):
        self.__db = sqlite3.connect(CONFIG['db'])
        super().__init__(request, client_address, server)

    def query_db(self, command, params=tuple()):
        """
        Query local database
        """
        return self.__db.cursor().execute(command, params)

    def __del__(self):
        self.__db.commit()
        self.__db.close()

    def respond(self, body, contenttype, code=200, encoding="utf-8"):
        """
        Respond to HTTP request.
        """
        self.send_response(code)
        self.send_header("Content-Type", contenttype)
        self.end_headers()
        self.write_response(body.encode(encoding))

    def respond_html(self, body=None, filename=None, code=200):
        """
        Respond with HTML
        """
        if body is None:
            body = open(filename, 'r').read()
        self.respond(body, "text/html", code=code)

    def respond_text(self, body, code=200):
        """
        Respond with plain/text
        """
        self.respond(body, "text/plain", code=code)

    def do_GET(self):
        # pylint: disable-msg=C0103
        """
        Handle GET request
        """
        if self.path == "/":
            self.respond_html(filename='hangman.html')
        elif self.path == "/game":
            game_screen = "\n".join([x[0] for x in self.query_db("Select * From game")])
            self.respond_text(game_screen)
        else:
            error_msg = """
                <h1><code>500</code> ERROR</h1>
            """
            self.respond_html(error_msg, 500)

    def write_response(self, body):
        """
        Write response
        """
        self.wfile.write(body)

    def postdata(self):
        """
        Retrieve POST data
        """
        try:
            content_length = int(self.headers['Content-Length'])
        except KeyError:
            content_length = 0
        return self.rfile.read(content_length)

    def do_POST(self):
        # pylint: disable-msg=C0103
        """
        Handle POST request
        """
        if self.path == "/letter":
            letter = json.loads(self.postdata())['letter']
            self.query_db("""
                Insert Into game Select ?
            """, (letter, ))
            self.respond_text("OK")
        elif self.path == "/level":
            level = json.loads(self.postdata())['level']
            self.query_db("""
                Insert Or Replace Into level Select 1, ?
            """, (level, ))
            self.respond_text("OK")
        elif self.path == "/restart":
            self.query_db("""
                Insert Into game Select 'start'
            """)
            self.respond_text("OK")
        elif self.path == "/undo":
            self.query_db("""
                Delete From guesses
                Where rowid = (Select max(rowid) From guesses)
            """)
            self.respond_text("OK")
        else:
            error_msg = """
                <h1><code>500</code> ERROR</h1>
            """
            self.respond_html(error_msg, 500)


if __name__ == '__main__':
    start_hangman()
