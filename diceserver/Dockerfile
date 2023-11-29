FROM ruby:3.2.2

COPY . /root/

WORKDIR /root
RUN bundle install

EXPOSE 8081

CMD /usr/local/bin/bundle exec ruby main.rb
