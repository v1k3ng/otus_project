from bs4 import BeautifulSoup
from requests import get
from argparse import ArgumentParser
from re import findall, match
from functools import lru_cache
from time import time
from pika import BlockingConnection, ConnectionParameters, PlainCredentials
from os import getenv
from pymongo import MongoClient
from bson.objectid import ObjectId
import structlog
import logging
import traceback
import prometheus_client

PAGE_PARSED = prometheus_client.Counter('crawler_pages_parsed', 'Number of pages parsed by crawler')
HISTOGRAM_SITE_CONNECTION_TIME = prometheus_client.Histogram('crawler_site_connection_time', 'How much time it took for crawler to get page')
HISTOGRAM_PAGE_PARSE_TIME = prometheus_client.Histogram('crawler_page_parse_time', 'How much time it took to parse a page')

def connect_db():
    try:
        db = MongoClient(
            getenv('MONGO', 'mongo'),
            int(getenv('MONGO_PORT', '27017'))
        )
        db.admin.command('ismaster')
    except Exception as e:
        log.error('connect_db',
                  service='crawler',
                  message="Failed connect to Database",
                  traceback=traceback.format_exc(e),
                  )
    else:
        log.info('connect_to_db',
                  service='crawler',
                  message='Successfully connected to database',
                )
        return db

def connect_to_mq():
    try:
        credentials = PlainCredentials(mquser, mqpass)
        rabbit = BlockingConnection(ConnectionParameters(
            host=mqhost,
            connection_attempts=10,
            retry_delay=1,
            credentials=credentials))
    except Exception as e:
        log.error('connect_to_MQ',
                  service="crawler",
                  message="Failed connect to MQ",
                  traceback=traceback.format_exc()
                  )
    else:
        log.info('connect_to_MQ',
                  service="crawler",
                  message='Successfully connected to MQ host {}'.format(mqhost)
                )
        return rabbit.channel()


logg = logging.getLogger('werkzeug')
logg.disabled = True   # disable default logger

log = structlog.get_logger()
structlog.configure(processors=[
     structlog.processors.TimeStamper(fmt="%Y-%m-%d %H:%M:%S"),
     structlog.stdlib.add_log_level,
     # to see indented logs in the terminal, uncomment the line below
     # structlog.processors.JSONRenderer(indent=2, sort_keys=True)
     # and comment out the one below
     structlog.processors.JSONRenderer(sort_keys=True)
 ])

CHECK_INTERVAL = int(getenv('CHECK_INTERVAL', -1))

exclude_urls = list(filter(None, getenv('EXCLUDE_URLS', '').split(',')))

mqhost = getenv('RMQ_HOST', 'rabbit')
mqqueue = getenv('RMQ_QUEUE', 'urls')

mquser = getenv('RMQ_USERNAME', 'guest')
mqpass = getenv('RMQ_PASSWORD', 'guest')

def new_word(word):
    return db.words.insert( {'word': word})

def get_word(word):
    return db.pages.find_one( {'word': word }  )

def get_word_id(word):
    search = get_word(word)
    if search and '_id' in search:
        return search['_id']
    return search

def new_word_page(word_id,page_id):
    db.words.find_one_and_update( {'_id': word_id }, { '$addToSet': { 'ref_pages': page_id }} )

def get_word_page(word_id,page_id):
    search = db.words.find_one({ '_id': word_id })
    if search and 'ref_pages' in search:
        return page_id in search['ref_pages']
    return False

def get_page(url):
    return db.pages.find_one( {'url': url} )

def get_page_id(url):
    search = get_page(url)
    print(search)
    if search and '_id' in search:
        return search['_id']
    return search

def new_page(url):
    return db.pages.insert( {'url': url, 'checked': ''} )

def set_check_page(page_id,check):
    db.pages.find_one_and_update( {'id': page_id }, {'$set': {'checked': check } })

def new_page_page(page_id, ref_page_id):
    db.pages.find_one_and_update({'_id': page_id }, { '$addToSet': {'ref_pages': ref_page_id }})

def get_page_page(page_id,ref_page_id):
    search = db.pages.find_one( {'_id': page_id} )
    if search and 'ref_pages' in search:
        return ref_page_id in search['ref_pages']
    return False

def get_page_content(url):
    start_time = time()
    page = get(url)
    stop_time = time()
    HISTOGRAM_SITE_CONNECTION_TIME.observe(stop_time - start_time)
    return page.content

def prepare_links(soup):
    links = []
    for link in soup.find_all('a'):
        url = link.get('href')
        if url:
            links.append(url.strip())
    return links

def prepare_text(contents):
    start_time = time()
    soup = BeautifulSoup(contents, 'html.parser')

    for script in soup(["script", "style"]):
        script.extract()

    res = (findall(r"[\w']+", soup.get_text()), prepare_links(soup))
    stop_time = time()
    HISTOGRAM_PAGE_PARSE_TIME.observe(stop_time - start_time)
    return res

def parse_page(url):
    try:
        contents = get_page_content(url)
    except Exception as e:
        log.error('parse_page',
                   service="crawler",
                   params=  {'url': url},
                   message="Failed",
                   traceback=traceback.format_exc()
                  )
        return (None, None)
    else:
        PAGE_PARSED.inc()
        log.info('parse_page',
                  service='crawler',
                  params={'url': url},
                  message="Success"
                 )
        return prepare_text(contents)


@lru_cache(maxsize=2**32)
def getsert_page_id(page):
    page_id = get_page_id(page)
    if not page_id:
        page_id = new_page(page)
    return page_id


@lru_cache(maxsize=2**32)
def getsert_page(page):
    page_obj = get_page(page)
    if not page_obj:
        page_id = new_page(page)
        checked = ''
    else:
        page_id = page_obj['_id']
        checked = page_obj['checked']
    return (page_id,checked)

@lru_cache(maxsize=2**32)
def getsert_word_id(word):
    word_id = get_word_id(word)
    if not word_id:
        word_id = new_word(word)
    return word_id

def prepare_url(new_url, url):
    if new_url.startswith('http'):
        pass
    elif new_url.startswith('//'):
        new_url = 'http:' + new_url
    elif new_url.startswith('/'):
        new_url = '/'.join(url.split('/')[0:3]) + new_url
    else:
        new_url = url.strip('/') + '/' + new_url
    return new_url

def callback(ch, method, properties, body):
    global db
    db_connection = connect_db()
    db = db_connection.search_engine
    url = body.decode('utf-8')
    for exclude in exclude_urls:
        if match(exclude, url):
            ch.basic_ack(method.delivery_tag)
            log.info('exclude_page',
                      service='crawler',
                      url=url,
                      message="Page excluded"
                     )
            return

    (page_id, checked) = getsert_page(url)
    if not checked or time() - checked > CHECK_INTERVAL:
        (words, urls) = parse_page(url)
        if not words and not urls:
            channel.basic_nack(method.delivery_tag)
            return
        for word in words:
            word_id = getsert_word_id(word)
            if not get_word_page(word_id, page_id):
                new_word_page(word_id, page_id)

        for new_url in urls:
            new_url = prepare_url(new_url, url)
            publish_url(new_url)
            new_page_id = getsert_page_id(new_url)
            if not get_page_page(new_page_id, page_id):
                new_page_page(new_page_id, page_id)

    channel.basic_ack(method.delivery_tag)
    set_check_page(page_id, int(time()))
    db_connection.close()


def publish_url(url):
    try:
        channel.basic_publish(exchange='',
                              routing_key=mqqueue,
                              body=url)
    except Exception as e:
        log.error('publish_url',
                  service="crawler",
                  params={'url': url},
                  message="Failed to publish URL in MQ",
                  traceback=traceback.format_exc())
    else:
        log.info('publish_url',
                  service='crawler',
                  params={'url': url},
                  message="Successfully published URL in MQ"
                 )

if __name__ == "__main__":

    channel = connect_to_mq()
    channel.queue_declare(queue=mqqueue)
    parser = ArgumentParser(description='Simple web crawler')
    parser.add_argument('url', help='URL to start')
    args = parser.parse_args()
    prometheus_client.start_http_server(8000)

    publish_url(args.url)
    channel.basic_consume(callback,
                      queue=mqqueue)
    channel.start_consuming()
