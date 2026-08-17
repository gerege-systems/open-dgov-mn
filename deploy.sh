#!/usr/bin/env bash
# open.dgov.mn-ийг шинэчлэх. Серверийн /opt/open-dgov-mn дотроос ажиллана.
#
#   REGISTRY_USER=<github-хэрэглэгч> REGISTRY_TOKEN=<read:packages токен> ./deploy.sh
#
# Юу хийдэг вэ: цөмийн compose файлыг ТҮГЖСЭН хувилбараар нь татаж, GHCR-ээс
# образуудыг татаж, стекийг солиод, эрүүл эсэхийг асууна. Энэ репод цөмийн код
# байхгүй тул шинэчлэлт гэдэг нь CORE_REF ба IMAGE_TAG хоёрыг өөрчлөх явдал.
set -euo pipefail

# Цөмийн түгжигдсэн хувилбар. compose файл болон nginx-ийн snippet хоёулаа
# эндээс ирнэ — салбарын толгойгоос биш: "өчигдөр ажиллаж байсан" гэдэг нь
# тодорхой commit байх ёстой, өнөөдрийн main биш.
CORE_REF="${CORE_REF:-d135c8871b0e5c0f99a25c0b316979d2e0c5f76c}"
CORE_RAW="https://raw.githubusercontent.com/gerege-systems/open-gerege-nexus/${CORE_REF}"

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

if [ ! -f .env ]; then
  echo "$APP_DIR/.env алга. .env.example-ээс хуулж, нууцуудыг нь бөглө." >&2
  exit 1
fi

# Бүрхүүл ./brand-ийг унших горимоор mount хийдэг тул байхгүй бол Docker
# өөрөө root-ийн эзэмшилтэй хавтас үүсгэнэ.
mkdir -p brand

curl -fsSL -o docker-compose.prod.yml "${CORE_RAW}/docker-compose.prod.yml"

# nginx-ийн OIDC snippet. Vhost үүнийг include хийдэг — байхгүй бол `nginx -t`
# унана, орхивол discovery-гийн хүсэлт бүрт бүрхүүлийн 404 хариулагдана.
if [ -w /etc/nginx/snippets ]; then
  curl -fsSL -o /etc/nginx/snippets/nexus-oauth.conf "${CORE_RAW}/deploy/nginx/snippets/nexus-oauth.conf"
fi

: "${REGISTRY_USER:?REGISTRY_USER шаардлагатай}"
: "${REGISTRY_TOKEN:?REGISTRY_TOKEN шаардлагатай (read:packages)}"
echo "$REGISTRY_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin

# Ажиллаж байгаа контейнеруудыг образ хост дээр буусны дараа л хөндөнө: pull
# унасны дараах татан буулгалт бол амжилтгүй deploy биш, тасалдал.
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --remove-orphans

docker logout ghcr.io >/dev/null

# Шалгалт: гурван хариу — API эрүүл, бүрхүүл ирж байна, брэнд .env-ийнхээ
# нэрийг хэлж байна. Гурав дахь нь энэ байрлуулалтыг цөмийн анхдагчаас
# ялгадаг цорын ганц зүйл тул сайн дурын биш.
port_backend="$(grep -E '^BACKEND_HOST_PORT=' .env | cut -d= -f2)"; port_backend="${port_backend:-8082}"
port_frontend="$(grep -E '^FRONTEND_HOST_PORT=' .env | cut -d= -f2)"; port_frontend="${port_frontend:-3008}"

for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${port_backend}/health" >/dev/null 2>&1; then break; fi
  [ "$i" -eq 30 ] && { echo "backend 60 секундэд эрүүл болсонгүй" >&2; docker compose -f docker-compose.prod.yml logs --tail 40 backend >&2; exit 1; }
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
