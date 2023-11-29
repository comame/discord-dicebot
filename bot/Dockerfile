FROM ubuntu

RUN apt update -y && apt install -y ca-certificates

COPY ./out /root/out

EXPOSE 8080

CMD "/root/out"
