import os
from ui import ui
import unittest
import tempfile
import mongomock

def mock():
    db = mongomock.MongoClient()
    return db

ui.connect_db = mock

class TestWebUI(unittest.TestCase):


    def setUp(self):
        self.app = ui.app.test_client()

    def test_empty_db(self):
        rv = self.app.get('/')
        assert b'Best search engine ever' in rv.data
    
if __name__ == '__main__':
    unittest.main()