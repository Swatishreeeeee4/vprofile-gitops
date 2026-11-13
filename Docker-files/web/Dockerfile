FROM nginx:1.27
LABEL project="vprofile" tier="web"
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginvproapp.conf /etc/nginx/conf.d/vproapp.conf
