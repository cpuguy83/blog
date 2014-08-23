FROM ruby:2.1.2
RUN gem install jekyll therubyracer --no-ri --no-rdoc
ADD . /opt/site
WORKDIR /opt/site
RUN jekyll build && cp -r _site site && tar -cvvf site.tar site && gzip -9 site.tar && rm -rf site
CMD cat site.tar.gz
