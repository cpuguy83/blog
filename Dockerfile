FROM ruby:2.6 AS base
WORKDIR /opt/site
COPY Gemfile* /opt/site/
RUN bundle install

FROM base AS build
ADD . /opt/site
RUN jekyll build

FROM base AS dev
CMD jekyll serve --host 0.0.0.0

FROM nginx AS final
COPY --from=build /opt/site/_site /usr/share/nginx/html
