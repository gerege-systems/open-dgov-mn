// Package zarlal — байгууллагын доторх зарлал.
//
// Энэ бол open.dgov.mn-ий өөрийн эхний модуль: цөмд байхгүй, зөвхөн энэ
// байрлуулалтын хэрэгцээ. Мөн шинэ модуль бичих загвар — Module интерфэйсийн
// долоон метод, өөрийн нэг хүснэгт, өөрийн гурван маршрут, өөрөө зарласан
// эрхүүд. Өөр модуль нэмэх нь энэ хавтасны хажууд нэг хавтас, main.go-д нэг
// мөр.
//
// Эрхийн загвар нь энгийн: RoutePermissionPrefix буцаасны дараа платформ
// GET-ийг `zarlal.read`-ээр, өөрчлөлт хийх бүх хүсэлтийг `zarlal.manage`-ээр
// хаана. Суулгах үед `.read`-ийг гишүүн бүр авдаг, `.manage`-ийг админ авдаг —
// зарлалыг бүгд уншиж, цөөхөн хүн нийтэлдэг гэсэн үг.
package zarlal

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/nexus"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type Announcement struct {
	ID        string     `json:"id"`
	TenantID  string     `json:"tenant_id"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	Pinned    bool       `json:"pinned"`
	CreatedBy string     `json:"created_by"`
	CreatedAt time.Time  `json:"created_at"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
}

type Module struct {
	db nexus.DB
}

// New нь платформыг бүхэлд нь авдаг, үйлчилгээ тус бүрээр биш: цаг хугацааны
// явцад платформ модульд илүү зүйл зээлдэг бөгөөд дуудалт бүрд нэг параметр
// нэмэгддэг конструктор бол байрлуулалт бүр хөөцөлдөх ёстой гарын үсэг болно.
func New(p nexus.Platform) *Module {
	m := &Module{db: p.DB()}
	nexus.Register(m)
	return m
}

func (m *Module) ID() string      { return "mn.dgov.zarlal" }
func (m *Module) Name() string    { return "Announcements" }
func (m *Module) Version() string { return "1.0.0" }

// nexus.AccessPolicy — платформ энэ модулийн эрхийг хаана шалгахыг өөрөө
// мэдэхгүй, модуль нь хэлж өгнө.
func (m *Module) MenuPermission() string        { return "zarlal.read" }
func (m *Module) RoutePermissionPrefix() string { return "zarlal" }

func (m *Module) Dependencies() []nexus.Dependency { return nil }

func (m *Module) Permissions() []nexus.PermissionDefinition {
	return []nexus.PermissionDefinition{
		{Code: "zarlal.read", Name: "Read announcements", Description: "See this organisation's announcements"},
		{Code: "zarlal.manage", Name: "Post announcements", Description: "Post and withdraw announcements"},
	}
}

func (m *Module) Menus() []nexus.MenuDefinition {
	return []nexus.MenuDefinition{
		// Зам нь бүрхүүлийн ерөнхий `app/module/[app]` дэлгэц рүү заана. Цөмийн
		// бүрхүүл нь нэг образ, бүх байрлуулалтад үйлчилдэг тул энэ модуль
		// өнөөдөр өөрийн дэлгэцгүй — API нь ажиллана, дэлгэц нь орлуулагч.
		// Жинхэнэ дэлгэц хэрэгтэй болох өдөр тэр нь цөмийн бүрхүүлд
		// нэмэгдэнэ (ECOSYSTEM_GIT_STRATEGY §2.3-ийн 2026-08-15-ны шийдвэр).
		{
			ID: "zarlal", Label: "Announcements", Path: "/module/dgov-zarlal",
			Icon: "megaphone", Order: 15,
			Labels: map[string]string{"mn": "Зарлал"},
		},
	}
}

func (m *Module) RegisterRoutes(r chi.Router, tenantAuthMiddleware func(http.Handler) http.Handler) {
	r.Route("/api/v1/dgov/zarlal", func(zr chi.Router) {
		zr.Use(tenantAuthMiddleware)
		zr.Get("/", m.list)
		zr.Post("/", m.post)
		zr.Delete("/{id}", m.withdraw)
	})
}

// draft бол хүсэлтийн бие. Шалгалт нь тусдаа метод байгаа нь санаатай: HTTP,
// сан хоёргүйгээр туршиж болох цорын ганц хэсэг нь энэ.
type draft struct {
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	Pinned    bool       `json:"pinned"`
	ExpiresAt *time.Time `json:"expires_at"`
}

const maxTitle = 200

func (d draft) validate(now time.Time) error {
	switch {
	case d.Title == "" || d.Body == "":
		return errors.New("title and body are required")
	case len(d.Title) > maxTitle:
		return errors.New("title is too long")
	case d.ExpiresAt != nil && !d.ExpiresAt.After(now):
		// Аль хэдийн дууссан зарлал бол хэн ч харахгүй мөр: жагсаалт нь
		// хугацаагаар шүүдэг тул үүнийг зөвшөөрөх нь чимээгүй алдагдсан
		// нийтлэл.
		return errors.New("expires_at is already past")
	}
	return nil
}

func (m *Module) list(w http.ResponseWriter, r *http.Request) {
	tenantID, ok := nexus.RequireTenant(w, r)
	if !ok {
		return
	}

	rows, err := m.db.Query(r.Context(),
		`SELECT id, tenant_id, title, body, pinned, created_by, created_at, expires_at
		   FROM dgov_announcement
		  WHERE tenant_id = $1 AND (expires_at IS NULL OR expires_at > NOW())
		  ORDER BY pinned DESC, created_at DESC`, tenantID)
	if err != nil {
		nexus.Error(w, http.StatusInternalServerError, "database error")
		return
	}
	defer rows.Close()

	list := make([]Announcement, 0)
	for rows.Next() {
		var a Announcement
		if err := rows.Scan(&a.ID, &a.TenantID, &a.Title, &a.Body, &a.Pinned,
			&a.CreatedBy, &a.CreatedAt, &a.ExpiresAt); err != nil {
			nexus.Error(w, http.StatusInternalServerError, "scan error")
			return
		}
		list = append(list, a)
	}
	// Тасарсан урсгал нь бүтэн урсгалтай яг адилхан давталтыг дуусгадаг;
	// үүнгүйгээр таслагдсан жагсаалт 200-аар гарна.
	if err := rows.Err(); err != nil {
		nexus.Error(w, http.StatusInternalServerError, "scan error")
		return
	}

	nexus.JSON(w, http.StatusOK, list)
}

func (m *Module) post(w http.ResponseWriter, r *http.Request) {
	claims, err := nexus.UserFromContext(r.Context())
	if err != nil {
		nexus.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var d draft
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		nexus.Error(w, http.StatusBadRequest, "invalid payload")
		return
	}
	now := time.Now()
	if err := d.validate(now); err != nil {
		nexus.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	a := Announcement{
		ID: uuid.NewString(), TenantID: claims.TenantID,
		Title: d.Title, Body: d.Body, Pinned: d.Pinned,
		CreatedBy: claims.UserID, CreatedAt: now, ExpiresAt: d.ExpiresAt,
	}
	_, err = m.db.Exec(r.Context(),
		`INSERT INTO dgov_announcement
		        (id, tenant_id, title, body, pinned, created_by, created_at, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		a.ID, a.TenantID, a.Title, a.Body, a.Pinned, a.CreatedBy, a.CreatedAt, a.ExpiresAt)
	if err != nil {
		nexus.Error(w, http.StatusInternalServerError, "database error")
		return
	}

	nexus.Audit(r.Context(), claims.TenantID, claims.UserID, "zarlal.post", a.ID,
		map[string]any{"title": a.Title})
	nexus.JSON(w, http.StatusCreated, a)
}

func (m *Module) withdraw(w http.ResponseWriter, r *http.Request) {
	claims, err := nexus.UserFromContext(r.Context())
	if err != nil {
		nexus.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	id := chi.URLParam(r, "id")
	// tenant_id нь WHERE-д байгаа нь заавал: мөрийн түвшний бодлого үүнийг
	// давхар барьдаг ч, бодлого унтарсан холболт дээр энэ мөр л өөр
	// байгууллагын зарлалыг устгахаас сэргийлнэ.
	res, err := m.db.Exec(r.Context(),
		`DELETE FROM dgov_announcement WHERE id = $1 AND tenant_id = $2`, id, claims.TenantID)
	if err != nil {
		nexus.Error(w, http.StatusInternalServerError, "database error")
		return
	}
	if res.RowsAffected() == 0 {
		nexus.Error(w, http.StatusNotFound, "announcement not found")
		return
	}

	nexus.Audit(r.Context(), claims.TenantID, claims.UserID, "zarlal.withdraw", id, nil)
	nexus.JSON(w, http.StatusOK, map[string]string{"status": "withdrawn"})
}
