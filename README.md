# Цахим Засаг — open.dgov.mn

[Gerege Nexus](https://github.com/gerege-systems/open-gerege-nexus) платформын
**Түвшин 1 байрлуулалт**: код байхгүй, тохиргоо л байна.

Энэ репод Go файл ч, миграц ч, каталог ч байхгүй нь дутуу хийсэн ажил биш —
`docs/ECOSYSTEM_GIT_STRATEGY.md` §1-ийн сонголтын дүрэм: *"тохиргоо хүрэлцэхгүй
болохоор л Түвшин 2 руу"*. Төрийн үйлчилгээний дэлгэцүүд — `egov`,
`documents`, `organisation`, `reports`, `urtuu` — цөмд аль хэдийн байгаа тул
энэ байрлуулалтыг цөмөөс ялгах бүх зүйл нь нэр, домэйн, нэвтрэлтийн чиглэл:
дөрвөн файлд багтана.

Өөрийн Go модуль хэрэгтэй болох өдөр л энэ репо Түвшин 2 болно — тэр өдөр
`go.mod`, `main.go`, `modules/` нэмэгдэнэ, доорх файлууд байрандаа үлдэнэ.

```
.env.example                  бүх тохиргоо, тайлбартайгаа
nginx/open.dgov.mn.conf       vhost: бүрхүүл, API, OIDC, брэндийн зураг
deploy.sh                     цөмийн compose-ыг түгжсэн хувилбараар нь татаж шинэчилнэ
first-admin.sh                эхний байгууллага, эхний админ
```

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
түгжигдсэн** commit-оос татна. Цөмийг шинэчилнэ гэдэг нь энэ репод хоёр мөр
өөрчлөх ажил: `CORE_REF` ба `.env`-ийн `IMAGE_TAG`. Compose файлыг энд хуулж
тавихгүй байгаа нь санаатай — хуулбар бол цөмөөс чимээгүй хоцрох арга.

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
