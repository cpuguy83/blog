FROM ruby:2.2
RUN gem install therubyracer --no-ri --no-rdoc
RUN gem install -v "=2.5.3" jekyll
RUN apt-get update && apt-get install -y nginx ca-certificates --no-install-recommends
ADD . /opt/site
WORKDIR /opt/site
RUN jekyll build
RUN mv /etc/nginx/nginx.conf /tmp/nginx.conf && echo "daemon off;" > /etc/nginx/nginx.conf && cat /tmp/nginx.conf >> /etc/nginx/nginx.conf && rm /tmp/nginx.conf
ADD site.conf /etc/nginx/sites-available/default
EXPOSE 80
CMD ["nginx"]
