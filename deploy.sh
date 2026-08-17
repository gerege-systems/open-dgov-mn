#!/usr/bin/env bash
# open.dgov.mn-ийг шинэчлэх. Серверийн /opt/open-dgov-mn дотроос ажиллана.
#
#   REGISTRY_USER=<github-хэрэглэгч> REGISTRY_TOKEN=<read:packages токен> ./deploy.sh
#
# Юу хийдэг вэ: цөмийн compose файлыг ТҮГЖСЭН хувилбараар нь татаж, дээр нь
# энэ репогийн давхаргыг тавьж, GHCR-ээс образуудыг татаж, стекийг солиод,
# эрүүл эсэхийг асууна.
#
# Backend образ нь одоо энэ репогийнх (цөм + өөрийн модулиуд), CI угсарч GHCR
# рүү түлхдэг; бүрхүүл нь цөмийнх хэвээр. Тиймээс шинэчлэл гэдэг нь юуг
# хөдөлгөж байгаагаас хамаарна: өөрийн код бол go.mod ба IMAGE_TAG, цөмийн
# compose/nginx бол доорх CORE_REF, бүрхүүл бол FRONTEND_TAG.
set -euo pipefail

# Цөмийн түгжигдсэн хувилбар. compose файл болон nginx-ийн snippet хоёулаа
# эндээс ирнэ — салбарын толгойгоос биш: "өчигдөр ажиллаж байсан" гэдэг нь
# тодорхой commit байх ёстой, өнөөдрийн main биш.
CORE_REF="${CORE_REF:-abeb27b5ea8e720bae0b76634acb489e74db470e}"
CORE_RAW="https://raw.githubusercontent.com/gerege-systems/open-gerege-nexus/${CORE_REF}"

# Бүрхүүлийн образын таг — CORE_REF-ийн адил ЭНД түгждэг, серверийн .env дээр
# биш. Хоёр газар байхад сервер дээрх нь хождог: репо шинэ бүрхүүл заасан
# атал суулгац хуучнаараа ажиллаж байсан өдөр (2026-08-17) яг ингэсэн.
# CI роллаут хийхэд гар засвар үлдээхгүй байх нь энэ мөрийн бүх зорилго.
export FRONTEND_TAG="${FRONTEND_TAG:-abeb27b5ea8e720bae0b76634acb489e74db470e}"

# Backend образын таг. CI өөрийн угсарсан commit-оо дамжуулна; гараар
# ажиллуулбал .env-ийнх (ихэвчлэн latest) хэвээр.
if [ -n "${IMAGE_TAG:-}" ]; then export IMAGE_TAG; fi

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

if [ ! -f .env ]; then
  echo "$APP_DIR/.env алга. .env.example-ээс хуулж, нууцуудыг нь бөглө." >&2
  exit 1
fi

# Бүрхүүл ./brand-ийг унших горимоор mount хийдэг тул байхгүй бол Docker
# өөрөө root-ийн эзэмшилтэй хавтас үүсгэнэ. chmod нь сайн дурын биш: nginx
# энэ лавлахаас /brand/… -г шууд өгдөг ба www-data 0700 дотор орж чадахгүй —
# лого тавьсны дараа л мэдэгддэг 403.
mkdir -p brand && chmod 755 brand

# GitHub-ийн raw нь нэг IP-аас олон татахад 429 хариулдаг ба энэ хост дээр
# хоёр стек, өдөрт хэд хэдэн роллаут байдаг. Дахин оролдохгүй бол тэр хариу
# нь ажиллаж байгаа суулгацыг шинэчлэхээс татгалзсан deploy болно —
# 2026-08-17-нд яг ингэсэн.
fetch_core() {
  curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$1" "${CORE_RAW}/$2"
}

fetch_core docker-compose.prod.yml docker-compose.prod.yml

# Цөмийн compose, дээр нь энэ репогийн давхарга — гэхдээ зөвхөн .env нь энэ
# репогийн образыг зааж байвал. Давхарга нь тэр образыг хүлээдэг: өөрийн
# миграцын түүх нь түүн дотор /app/db/dgov байдаг тул цөмийн образ дээр
# migrate-dgov нь хавтас олдохгүй гэж унана.
#
# Хоёр салаа байгаа нь шилжилтийн үе учраас: серверийн .env цөмийн образыг
# заасан хэвээр байна. Тэр мөрийг солих нь Түвшин 2 рүү шилжих алхам өөрөө
# (README-гийн "Шинэчлэх") бөгөөд шилжсэний дараа энэ нөхцөл хасагдана.
compose=(docker compose -f docker-compose.prod.yml)
if grep -qE '^IMAGE_BACKEND=.*open-dgov-mn' .env; then
  compose+=(-f deploy/compose.dgov.yml)
else
  echo "IMAGE_BACKEND нь цөмийн образыг зааж байна — энэ репогийн модулиуд ачаалагдахгүй." >&2
  echo "Шилжихдээ: IMAGE_BACKEND=ghcr.io/gerege-systems/open-dgov-mn/backend" >&2
fi

# nginx-ийн OIDC snippet. Vhost үүнийг include хийдэг — байхгүй бол `nginx -t`
# унана, орхивол discovery-гийн хүсэлт бүрт бүрхүүлийн 404 хариулагдана.
if [ -w /etc/nginx/snippets ]; then
  fetch_core /etc/nginx/snippets/nexus-oauth.conf deploy/nginx/snippets/nexus-oauth.conf
fi

: "${REGISTRY_USER:?REGISTRY_USER шаардлагатай}"
: "${REGISTRY_TOKEN:?REGISTRY_TOKEN шаардлагатай (read:packages)}"
echo "$REGISTRY_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin

# Ажиллаж байгаа контейнеруудыг образ хост дээр буусны дараа л хөндөнө: pull
# унасны дараах татан буулгалт бол амжилтгүй deploy биш, тасалдал.
"${compose[@]}" pull
"${compose[@]}" up -d --remove-orphans

docker logout ghcr.io >/dev/null

# Шалгалт: гурван хариу — API эрүүл, бүрхүүл ирж байна, брэнд .env-ийнхээ
# нэрийг хэлж байна. Гурав дахь нь энэ байрлуулалтыг цөмийн анхдагчаас
# ялгадаг цорын ганц зүйл тул сайн дурын биш.
port_backend="$(grep -E '^BACKEND_HOST_PORT=' .env | cut -d= -f2)"; port_backend="${port_backend:-8082}"
port_frontend="$(grep -E '^FRONTEND_HOST_PORT=' .env | cut -d= -f2)"; port_frontend="${port_frontend:-3008}"

for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${port_backend}/health" >/dev/null 2>&1; then break; fi
  [ "$i" -eq 30 ] && { echo "backend 60 секундэд эрүүл болсонгүй" >&2; "${compose[@]}" logs --tail 40 backend migrate >&2; exit 1; }
  sleep 2
done

# Бүрхүүл нь backend эрүүл болсны дараа хэдэн секунд асдаг тул нэг удаагийн
# шалгалт нь эрүүл rollout-ыг унасан гэж дуудна — эхний оролдлого дээр яг
# ингэсэн.
brand="$(grep -E '^BRAND_NAME=' .env | cut -d= -f2-)"
for i in $(seq 1 30); do
  if body="$(curl -fsS "http://127.0.0.1:${port_frontend}/login" 2>/dev/null)"; then
    [ -z "$brand" ] && break
    case "$body" in *"$brand"*) break ;; esac
  fi
  [ "$i" -eq 30 ] && { echo "бүрхүүл 60 секундэд «${brand:-хариу}» өгсөнгүй" >&2; exit 1; }
  sleep 2
done

echo "OK: $(grep -E '^PUBLIC_ORIGIN=' .env | cut -d= -f2) — $brand"
