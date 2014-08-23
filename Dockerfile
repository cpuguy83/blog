FROM ruby:2.1.2
RUN gem install jekyll therubyracer --no-ri --no-rdoc
ADD . /opt/site
WORKDIR /opt/site
ENTRYPOINT ["jekyll"]
CMD ["build"]
