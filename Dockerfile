FROM node:lts-alpine as builder

WORKDIR /opt/reporting-hub-bop-shell
ENV PATH /opt/reporting-hub-bop-shell/node_modules/.bin:$PATH

RUN apk add --no-cache -t build-dependencies git make gcc g++ python libtool autoconf automake \
    && cd $(npm root -g)/npm \
    && npm config set unsafe-perm true \
    && npm install -g node-gyp

COPY package.json /opt/reporting-hub-bop-shell/
COPY yarn.lock /opt/reporting-hub-bop-shell/
RUN yarn --frozen-lockfile

COPY ./ /opt/reporting-hub-bop-shell/

# Adds the package version and commit hash
ARG REACT_APP_VERSION
ENV REACT_APP_VERSION=$REACT_APP_VERSION

ARG REACT_APP_COMMIT
ENV REACT_APP_COMMIT=$REACT_APP_COMMIT

# Public Path - Placeholder that is overwritten at runtime
ARG PUBLIC_PATH
ENV PUBLIC_PATH=__PUBLIC_PATH__

RUN yarn build

# Second part, create a config at boostrap via entrypoint and and serve it
FROM nginx:1.16.0-alpine

# JQ is used to convert from JSON string to json file in bash
RUN apk add --no-cache jq

COPY --from=builder /opt/reporting-hub-bop-shell/dist/ /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf /etc/nginx/nginx.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/start.sh /usr/share/nginx/start.sh

COPY docker/entrypoint.sh /usr/share/nginx/html/entrypoint.sh
COPY docker/createJSONConfig.sh /usr/share/nginx/html/createJSONConfig.sh
COPY docker/createRemoteConfig.sh /usr/share/nginx/html/createRemoteConfig.sh
COPY docker/loadRuntimeConfig.sh /usr/share/nginx/html/loadRuntimeConfig.sh

RUN chmod +x /usr/share/nginx/html/entrypoint.sh
RUN chmod +x /usr/share/nginx/html/createJSONConfig.sh
RUN chmod +x /usr/share/nginx/html/createRemoteConfig.sh
RUN chmod +x /usr/share/nginx/html/loadRuntimeConfig.sh

# Provide environment variables for setting endpoints dynamically
ARG REMOTE_API_BASE_URL
ENV REMOTE_API_BASE_URL=$REMOTE_API_BASE_URL

ARG REMOTE_MOCK_API
ENV REMOTE_MOCK_API=$REMOTE_MOCK_API

ARG AUTH_API_BASE_URL
ENV AUTH_API_BASE_URL=$AUTH_API_BASE_URL

ARG AUTH_MOCK_API
ENV AUTH_MOCK_API=$AUTH_MOCK_API

ARG AUTH_ENABLED
ENV AUTH_ENABLED=$AUTH_ENABLED

ARG LOGIN_URL
ENV LOGIN_URL=$LOGIN_URL

ARG LOGOUT_URL
ENV LOGOUT_URL=$LOGOUT_URL

ARG REMOTE_1_URL
ENV REMOTE_1_URL=$REMOTE_1_URL

ARG REMOTE_2_URL
ENV REMOTE_2_URL=$REMOTE_2_URL

EXPOSE 8080

ENTRYPOINT ["/usr/share/nginx/html/entrypoint.sh"]

CMD ["sh", "/usr/share/nginx/start.sh"]
# TODO: Need to add 8080 to image-scan whitelist
#       Need to switch user away from root
#       Investigate Feed data unavailable, cannot perform CVE scan for distro: alpine:3.14.2
