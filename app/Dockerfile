FROM nginx:1.27-alpine

# Работаем от непривилегированного пользователя nginx (uid 101), который уже
# есть в базовом образе. Порт 8080 вместо 80 — непривилегированному процессу
# порты ниже 1024 недоступны.
COPY nginx.conf /etc/nginx/nginx.conf
COPY static/ /usr/share/nginx/html/

# Каталоги, в которые nginx пишет во время работы.
RUN chown -R nginx:nginx /var/cache/nginx /usr/share/nginx/html \
    && touch /var/run/nginx.pid \
    && chown nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
