from flask import Flask, request, g, render_template, logging, Response
from functools import reduce
from os import getenv
import uuid
import time
import structlog
from pymongo import MongoClient
import traceback
import prometheus_client

CONTENT_TYPE_LATEST = str('text/plain; version=0.0.4; charset=utf-8')
COUNTER_PAGES_SERVED = prometheus_client.Counter('web_pages_served', 'Number of pages served by frontend')
HISTOGRAM_PAGE_GEN_TIME = prometheus_client.Histogram('web_page_gen_time', 'Page generation time')

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

app = Flask(__name__)
def connect_db():
    try:
        db = MongoClient(
            getenv('MONGO', 'mongo'),
            int(getenv('MONGO_PORT', '27017'))
        )
        db.admin.command('ismaster')
    except Exception as e:
        log.error('connect_db',
                  service='web',
                  message="Failed connect to Database",
                  traceback=traceback.format_exc(e),
                  )
    else:
        log.info('connect_to_db',
                  service='web',
                  message='Successfully connected to database',
                )
        return db

def get_word(word):
    return g.db.words.find_one( {'word': word }  )

def get_word_id(word):
    search = get_word(word)
    if search and '_id' in search:
        return search['_id']
    return None

def get_pages_id (word_id):
    search = g.db.words.find_one({ '_id': word_id })
    if search and 'ref_pages' in search:
        return search['ref_pages']
    return None

def get_page_by_id (page_id):
    return g.db.pages.find_one( {'_id': page_id} )

def get_page_score (page_id):
    page = get_page_by_id(page_id)
    return len(page['ref_pages']) if page and 'ref_pages' in page else 0

def intersect(a, b):
    return list(set(a) & set(b))

@app.before_request
def before_request():
    g.request_start_time = time.time()
    g.db_connection = connect_db()
    g.db = g.db_connection.search_engine
    g.request_time = lambda: (time.time() - g.request_start_time)

@app.route('/metrics')
def metrics():
    return Response(prometheus_client.generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/')
def start():
    phrase = request.args.get('query', '').split()
    COUNTER_PAGES_SERVED.inc()

    if not phrase:
        return render_template('index.html', gen_time=g.request_time())

    word_ids = []
    for word in phrase:
        word_id = get_word_id(word)
        print(word_id)
        if not word_id:
            return render_template('index.html', gen_time=g.request_time())
        word_ids.append(word_id)

    pages_ids = {}
    for word_id in word_ids:
        pages_ids[word_id] = get_pages_id(word_id)

    pages = reduce(intersect, [pages_ids[word_id] for word_id in pages_ids])

    res = []
    for page_id in pages:
        url = get_page_by_id(page_id)['url']
        score = get_page_score(page_id)
        res.append((score, url))
    res.sort(reverse=True)

    return render_template('index.html', gen_time=g.request_time(), result=res)

@app.after_request
def after_request(response):
    HISTOGRAM_PAGE_GEN_TIME.observe(g.request_time())
    request_id = request.headers['Request-Id'] \
        if 'Request-Id' in request.headers else uuid.uuid4()
    log.info('request',
             service='web',
             request_id=request_id,
             addr=request.remote_addr,
             path=request.path,
             args=request.args,
             method=request.method,
             response_status=response.status_code)
    return response

@app.teardown_appcontext
def close_db(error):
    if hasattr(g, 'db_connection'):
        g.db_connection.close()

# Log Exceptions
@app.errorhandler(Exception)
def exceptions(e):
    request_id = request.headers['Request-Id'] \
        if 'Request-Id' in request.headers else None
    tb = traceback.format_exc()
    log.error('internal_error',
              service='web',
              request_id=request_id,
              addr=request.remote_addr,
              path=request.path,
              args=request.args,
              method=request.method,
              traceback=tb)
    return 'Internal Server Error', 500
