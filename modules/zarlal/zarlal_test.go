package zarlal

import (
	"strings"
	"testing"
	"time"
)

func TestDraftValidation(t *testing.T) {
	now := time.Date(2026, 8, 17, 9, 0, 0, 0, time.UTC)
	past := now.Add(-time.Hour)
	future := now.Add(time.Hour)

	cases := []struct {
		name  string
		draft draft
		ok    bool
	}{
		{"бүрэн", draft{Title: "Амралтын өдөр", Body: "Ажиллана"}, true},
		{"хугацаатай", draft{Title: "т", Body: "б", ExpiresAt: &future}, true},
		{"гарчиггүй", draft{Body: "б"}, false},
		{"биегүй", draft{Title: "т"}, false},
		{"хэт урт гарчиг", draft{Title: strings.Repeat("т", maxTitle+1), Body: "б"}, false},
		// Хэн ч харахгүй мөр: жагсаалт нь хугацаа дууссаныг шүүнэ.
		{"өнгөрсөн хугацаа", draft{Title: "т", Body: "б", ExpiresAt: &past}, false},
	}

	for _, c := range cases {
		err := c.draft.validate(now)
		if c.ok && err != nil {
			t.Errorf("%s: %v", c.name, err)
		}
		if !c.ok && err == nil {
			t.Errorf("%s: алдаа буцаах ёстой байсан", c.name)
		}
	}
}
