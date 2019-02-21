.PHONY: dev
dev: build/dev
	docker run -it -p 4000:4000 --rm -v $(PWD):/opt/site --tmpfs /opt/site/_site $(shell cat build/dev)

build/dev: build
	docker build --target=dev -t cpuguy83/blog-dev  --iidfile=build/dev .

.PHONY: clean
clean:
	rm -rf ./build

build:
	mkdir build
