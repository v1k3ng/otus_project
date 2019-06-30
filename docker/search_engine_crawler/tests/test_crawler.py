import unittest
from crawler import crawler

class TestCrawler(unittest.TestCase):
    def test_page_parse(self):
        content = '<a href="http://www.example.com/">Example URL</a>'
        assert crawler.prepare_text(content) == (['Example', 'URL'], ['http://www.example.com/'])

if __name__ == '__main__':
    unittest.main()