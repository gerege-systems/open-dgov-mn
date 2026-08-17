# Цахим Засаг — open.dgov.mn

[Gerege Nexus](https://github.com/gerege-systems/open-gerege-nexus) платформын
**Түвшин 2 distribution**: цөм нь хамаарал, дээр нь энэ байрлуулалтын өөрийн
Go модулиуд.

Энэ репо 2026-08-17 хүртэл Түвшин 1 — тохиргоо л — байсан. Өөрийн модуль
хэрэгтэй болох өдөр Түвшин 2 болно гэж бичсэн, тэр өдөр нь ирлээ. Өөрчлөгдөөгүй
зүйл: цөмийн код энд нэг ч мөр байхгүй, `go.mod`-ын нэг мөр л байна
(`docs/ECOSYSTEM_GIT_STRATEGY.md` §1). Төрийн үйлчилгээний дэлгэцүүд — `egov`,
`documents`, `organisation`, `reports`, `urtuu` — цөмд байгаа хэвээр; энд
байгаа нь цөмд байх ёсгүй зүйл.

```
main.go                       цөмийг асаахдаа өөрийн модулиудаа бүртгэнэ
modules/                      энэ байрлуулалтын Go модулиуд
migrations/                   тэдний хүснэгтүүд, өөрийн goose түүхэнд
catalog/                      тэдний апп сторын бичилт, манифест
deploy/Dockerfile             өөрийн backend образ (цөм + эдгээр модулиуд)
deploy/compose.dgov.yml       цөмийн compose дээрх давхарга
.env.example                  бүх тохиргоо, тайлбартайгаа
brand/                        лого ба landing page-ийн үгс — харагдах төрх
docs/                         docs.dgov.mn-ий эх, Pages-ээр нийтлэгддэг
nginx/open.dgov.mn.conf       vhost: бүрхүүл, API, OIDC, брэндийн зураг
deploy.sh                     образуудыг татаж стекийг солино
first-admin.sh                эхний байгууллага, эхний админ
```

## Өөрийн модуль бичих

Загвар нь `modules/zarlal` — байгууллагын доторх зарлал, цөмд байхгүй, ганц
хүснэгттэй, гурван маршруттай. Шинэ модуль нэмэх нь дөрвөн алхам:

1. `modules/<нэр>/<нэр>.go` — `nexus.Module`-ийн долоон метод, `New(p)` дотор
   `nexus.Register(m)`. Эрхээ `RoutePermissionPrefix()`-ээр зарлавал платформ
   GET-ийг `<prefix>.read`, өөрчлөлтийг `<prefix>.manage`-ээр хаана;
2. `migrations/0000N_<нэр>.sql` — хүснэгтүүд, доор нь `tenant_isolation`
   бодлого. Цөмийн 00029 нь тухайн үед байсан хүснэгтүүд дээр л ажилласан тул
   шинэ хүснэгт бүр өөрийн бодлогыг өөртөө авч явна;
3. `catalog/apps.json` + `catalog/manifests/<slug>.json` — эдгээргүй бол
   модуль бинарт байгаа боловч хэн ч суулгаж чадахгүй, маршрут бүр нь 403
   хариулна. `catalog_test.go` яг үүнийг барина;
4. `main.go`-д нэг мөр: `<нэр>.New(p)`.

`go test ./...` нь каталог, бинар хоёр зөрсөн эсэхийг хэлнэ — тэр зөрөө нь
production дээр чимээгүй унадаг цорын ганц зүйл. Бүрэн гарын авлага:
цөмийн `docs/MODULE_AUTHORING_GUIDE.md`.

**Дэлгэц нь өнөөдөр орлуулагч.** Бүрхүүл бол нэг образ, бүх суулгацад
үйлчилдэг тул distribution өөрийн дэлгэцээ аваачих механизм байхгүй
(§2.3, 2026-08-15-ны шийдвэр). Модулийн API ажиллана, цэсэнд гарна, харин
хуудас нь "Тун удахгүй". Жинхэнэ дэлгэц хэрэгтэй бол тэр нь цөмийн бүрхүүлд
нэмэгдэнэ.

## Хаана ажиллаж байна

**38.180.243.138** (Ubuntu 26.04, 4 CPU, 7GB). `open.dgov.mn`, `sso.dgov.mn`,
`dgov.mn` гурвуулаа энэ IP рүү заана; өнөөдөр зөвхөн эхнийх нь хариулна.

Байрлуулалт нь `/opt/open-dgov-mn/` — энэ репогийн клон, дотроо `.env`
(chmod 600) ба `brand/`. Портууд бүгд loopback дээр: 5434 postgres, 6381 redis,
8082 backend, 3008 бүрхүүл — цөмийн compose-ийн анхдагчид, учир нь энэ хост
дээр өөр стек байхгүй.

## Шинэчлэх

```bash
ssh root@38.180.243.138
cd /opt/open-dgov-mn && git pull
REGISTRY_USER=<github-хэрэглэгч> REGISTRY_TOKEN=<read:packages> ./deploy.sh
```

`deploy.sh` нь цөмийн `docker-compose.prod.yml`-ийг **`CORE_REF` дээр
түгжигдсэн** commit-оос татаж, дээр нь `deploy/compose.dgov.yml`-ийг тавина.
Compose файлыг энд хуулж тавихгүй байгаа нь санаатай — хуулбар бол цөмөөс
чимээгүй хоцрох арга.

Юуг хөдөлгөж байгаагаас хамаарч шинэчлэлт өөр өөр мөр дээр байна:

| Хөдөлгөх зүйл | Хаана | Одоо |
| --- | --- | --- |
| Энэ репогийн модулиуд | `main.go`/`modules/` → CI образ угсарна → `.env`-ийн `IMAGE_TAG` | `latest` |
| Цөмийн код (backend) | `go.mod`-ын `open-gerege-nexus/backend` таг | `v1.9.0` |
| Цөмийн compose, nginx snippet | `deploy.sh`-ийн `CORE_REF` | `c2e311e` |
| Бүрхүүл (харагдах төрх) | `.env`-ийн `FRONTEND_TAG` | `c2e311e` |

Backend образыг `.github/workflows/image.yml` угсарна: CI ногоон болсны дараа
`ghcr.io/gerege-systems/open-dgov-mn/backend` руу `latest` ба commit sha хоёр
тагаар түлхэнэ. Роллаут автомат биш — стекийг солих нь хүн харж байхад эхлэх
ажил.

**Үлдсэн нэг алхам: серверийн `.env`.** Ажиллаж байгаа стек `IMAGE_BACKEND`
дээрээ цөмийн образыг заасан хэвээр байгаа тул эндэх модулиуд хараахан
ачаалагдаагүй. Шилжүүлэх:

```bash
ssh root@38.180.243.138
sed -i 's|^IMAGE_BACKEND=.*|IMAGE_BACKEND=ghcr.io/gerege-systems/open-dgov-mn/backend|' /opt/open-dgov-mn/.env
cd /opt/open-dgov-mn && git pull
REGISTRY_USER=<github-хэрэглэгч> REGISTRY_TOKEN=<read:packages> ./deploy.sh
```

`deploy.sh` шилжсэн эсэхийг өөрөө мэднэ: заагаагүй бол цөмийн стекийг хэвээр
босгож, шилжээгүйг нь хэлнэ.

GHCR-ийн пакет хаалттай тул rollout бүр токеноор нэвтэрч, дараа нь гардаг.
Токеныг сервер дээр хадгалдаггүй.

## Нэвтрэлт

Энэ суулгац хүнийг **өөрөө таних биш, `sso.dgov.mn` дээр таниулна**
(`SSO_CLIENT_ISSUER`). Өөрөө өөрийн дээрээ суусан аппуудад identity тарааж
өгсөн хэвээр — `docs/SSO_FEDERATION.md`-ийн гурав дахь мөр.

Провайдер дээр бүртгэгдсэн клиент:

| | |
| --- | --- |
| `client_id` | `app_opendgovmn_28426259` |
| `client_type` | `confidential` |
| `redirect_uris` | `https://open.dgov.mn/api/v1/auth/sso/callback` |
| `post_logout_redirect_uris` | `https://open.dgov.mn/` |
| `grant_types` | `authorization_code` |
| `scopes` | `openid profile email` |

`client_id`-г провайдер өөрөө гаргадаг, гараар сонгодоггүй — тиймээс энэ мөр
`open-dgov-mn` биш. Нууцыг бүртгэсэн тэр нэг удаад л уншина: сан нь digest
хадгалдаг тул алдвал `rotate-secret`.

`open.dgov.mn` нь провайдерийн `OAUTH_REDIRECT_HOSTS` дотор яг таг байх ёстой —
тэр жагсаалт дэд домэйныг өвлүүлдэггүй.

**`SSO_CLIENT_LOCAL_LOGIN` нь `false`** (2026-08-17-ноос). Орох цорын ганц зам
нь `sso.dgov.mn`; эндэх нууц үгийн endpoint 403 хариулна.

Провайдер унавал буцах зам нь энэ нэг мөр:

```bash
ssh root@38.180.243.138
cd /opt/open-dgov-mn
sed -i 's|^SSO_CLIENT_LOCAL_LOGIN=.*|SSO_CLIENT_LOCAL_LOGIN=true|' .env
docker compose -f docker-compose.prod.yml up -d backend
```

## Эхний админ

```bash
cd /opt/open-dgov-mn && ./first-admin.sh <и-мэйл> <нууц үг>
```

Бүртгүүлэх дэлгэц байхгүй, control plane нь өөрийн vhost, TOTP шаарддаг тул
эхний хүн SQL-ээр ордог. Скрипт нь өөрөө нэвтэрч үзэж баталгаажуулна.

Аппуудыг API-аар суулгана, SQL-ээр биш:
`POST /api/v1/store/apps/{slug}/install` — суулгацын мөр нь каталог дүүргэдэг
`apps` хүснэгт рүү заадаг.
