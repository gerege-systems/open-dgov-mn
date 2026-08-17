# open.dgov.mn-ий өөрийн backend образ.
#
# Хоёр бинар — энэ байрлуулалтын сервер (цөм + энэ репогийн модулиуд) ба
# цөмийн миграц ажиллуулагч — дээр нь код биш, өгөгдөл болох файлууд: хоёр
# миграцын түүх, хоёр хагасаас нийлсэн нэг каталог.
#
# Юу нь модулийн кэшээс ирж байна, тэр нь хазайж чадахгүй: цөмийн миграцууд
# go.mod-ын түгжсэн хувилбараас гарна. Цөмийн каталог нь Go модулийн гадна,
# репогийн үндэст байдаг тул тэр нь ижил тагийн архиваас ирнэ — хоёулаа нэг
# хувилбар. Энд хуулж тавьсан хуулбар бол нэг JSON-ыг хоёр газар засах ажил
# бөгөөд аль нэг тал нь хөдөлмөгц зөрнө.
#
# Юу нь энэ репогийнх, тэр нь энд бичигдсэн: өөрийн миграцууд, өөрийн
# каталогийн бичилтүүд. Тэдгээр нь өөр хаанаас ч ирэх газаргүй.
#
# Хоёр хагас каталог нь ачаалах үед биш, энд нийлнэ: платформ нэг apps.json
# уншдаг тул каталогийнхаа хагасыг л барьсан суулгац цэвэрхэн асаад, нөгөө
# хагасынх нь бүртгүүлсэн маршрут бүрийг татгалзана.

FROM golang:1.26-alpine AS build

RUN apk add --no-cache git ca-certificates curl jq tar

WORKDIR /src

# Хамаарлууд эхлээд: өөрийн код өөрчлөгдөхөд цөмийг дахин татахгүй.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Энэ build нь апп сторд өөрийгөө юу гэж хэлэх вэ.
#
# Дамжуулж өгөх биш, go.mod-ын түгжсэн цөмийн хувилбараас гаргаж авна: учир нь
# энэ бол сонголт биш. PlatformVersion гэдэг нь манифест бүрийн
# `"platform": ">=1.7.0"`-ыг шалгах утга бөгөөд үнэн хариулт нь энэ образ дотор
# бодитоор компайл хийгдсэн платформын хувилбар. Build аргумент болговол
# 0.0.0 гэж анхдагчлах бөгөөд суулгац өөрийнхөө авчирсан манифест бүрийг
# татгалзана — өөрийн каталогоо уншиж чадахгүй тул асахгүй.
RUN core=$(go list -m -f '{{.Version}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && version=${core#v} \
    && echo "платформ ${version} нэрээр угсарч байна" \
    && CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-w -s -X github.com/gerege-systems/open-gerege-nexus/backend/internal/platform.PlatformVersion=${version}" \
    -o /bin/opendgov .

# Цөмийн миграц ажиллуулагч, энэ бүтээгдэхүүний хамаарлаас. Тэр модуль доторх
# пакет тул `go build` түүнийг бусад импорттой адил шийднэ.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" \
    -o /bin/migrate github.com/gerege-systems/open-gerege-nexus/backend/cmd/migrate

# Цөмийн миграцын файлууд — модуль доторх код биш, өгөгдөл. Зам нь хувилбараа
# өөртөө агуулдаг тул таамаглахын оронд буцааж уншина.
RUN core=$(go list -m -f '{{.Dir}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && mkdir -p /out/db && cp -r "$core/db/migrations" /out/db/migrations \
    && chmod -R u+w /out/db

# Цөмийн каталог. Go модуль нь `backend/`-оос эхэлдэг ба каталог нь репогийн
# үндэст байдаг тул модулийн кэшэд байхгүй — яг тэр тагийн архиваас авчирна.
# Хувилбарыг go.mod-оос уншиж байгаа нь чухал: каталог ба бинар хоёр өөр
# хувилбарынх байвал платформ өөрийн авчирсан аппуудыг таних эсэхээ мэдэхгүй.
RUN v=$(go list -m -f '{{.Version}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && mkdir -p /core \
    && curl -fsSL "https://codeload.github.com/gerege-systems/open-gerege-nexus/tar.gz/refs/tags/backend/${v}" \
       | tar -xz -C /core --strip-components=1 "open-gerege-nexus-backend-${v}/catalog" \
    && cp -r /core/catalog /out/catalog \
    && chmod -R u+w /out/catalog \
    && cp ./catalog/manifests/*.json /out/catalog/manifests/ \
    && jq -s 'add' /core/catalog/apps.json ./catalog/apps.json > /out/catalog/apps.json

FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata wget \
    && adduser -D -u 10001 dgov
ENV TZ=Asia/Ulaanbaatar

# Регистрээс татсан каталогийн кэш энд хадгалагдана. Цөмийн compose нь энэ
# замд volume холбодог тул хавтас нь энд, ажиллах хэрэглэгчийн эзэмшилтэйгээр
# үүсэх ёстой: Docker хоосон volume-д образын хавтасны эзэмшигчийг хуулдаг ба
# root-ийнх бол кэш бичигдэхгүй. Кэш унах нь үхэлд хүргэхгүй (лог бичээд дараа
# нь дахин босгоно) — яг тиймээс анзаарагдахгүй өнгөрөх байсан.
RUN mkdir -p /var/lib/nexus && chown dgov /var/lib/nexus

WORKDIR /app

COPY --from=build /bin/opendgov /app/opendgov
COPY --from=build /bin/migrate  /app/migrate
COPY --from=build /out/db       /app/db
COPY --from=build /out/catalog  /app/catalog
# Энэ репогийн өөрийн миграцууд, цөмийнхтэй нэг санд гэхдээ өөрийн түүхэнд:
# зөвхөн эндэх модулиудад хэрэгтэй хүснэгт нь платформын байрлуулалт бүр
# ажиллуулдаг миграцад байх ёсгүй. MIGRATIONS_DIR, MIGRATIONS_TABLE хосыг
# цөмийн cmd/migrate яг үүний тулд ургуулсан — deploy/compose.dgov.yml-ийг үз.
COPY migrations /app/db/dgov

USER dgov
EXPOSE 8080

CMD ["/app/opendgov"]
