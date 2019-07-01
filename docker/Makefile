.PHONY: build_all push_all

USER = mad72

build_all: build_search_engine_crawler \
			build_search_engine_ui \
			build_image_for_tests 

build_search_engine_crawler: search_engine_crawler
	docker build -t $(USER)/crawler-bot:latest search_engine_crawler

build_search_engine_ui: build_search_engine_ui
	docker build -t $(USER)/crawler-ui:latest search_engine_ui

build_image_for_tests: image_for_tests
	docker build -t $(USER)/bot-tests:latest image_for_tests

push_all: push_search_engine_crawler \
			push_search_engine_ui \
			push_image_for_tests 

push_search_engine_crawler: build_search_engine_crawler
	docker push $(USER)/crawler-bot:latest

push_search_engine_ui: build_search_engine_ui
	docker push $(USER)/crawler-ui:latest

push_image_for_tests: build_image_for_tests
	docker push $(USER)/bot-tests:latest
