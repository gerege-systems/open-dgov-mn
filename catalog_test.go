package main

import (
	"path/filepath"
	"testing"

	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/catalog"
	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/nexus"

	"github.com/gerege-systems/open-dgov-mn/modules/zarlal"
)

// Энэ репогийн каталог нь энэ репогийн модулиудтай тохирч байх ёстой. Образ
// үүнийг цөмийн каталогтой нийлүүлдэг тул энд шалгах зүйл бол өөрийн хагас.
//
// Хоёр чиглэл хоёулаа шалгагдана, хоёр дахь нь production дээр чимээгүй унадаг
// нь: бинарт байгаа боловч каталогт байхгүй модуль нь платформыг зогсоохгүй —
// verifyCatalogVersions нь танихгүй id-г алгасдаг, учир нь гадаад аппуудад
// модуль байхгүй нь хэвийн — зүгээр л хэн ч суулгаж чадахгүй, бүртгүүлсэн
// маршрут бүр нь хэн бүхэнд үүрд 403 хариулна. Өөр юу ч үүнийг хэлэхгүй.
func TestOurCatalogueAgreesWithOurModules(t *testing.T) {
	p := nexus.NewPlatform(nil, nil)
	ours := []nexus.Module{
		zarlal.New(p),
	}

	apps, err := catalog.LoadFile(filepath.Join("catalog", "apps.json"), "")
	if err != nil {
		t.Fatalf("энэ репогийн каталог ачаалагдахгүй байна: %v", err)
	}

	listed := make(map[string]string, len(apps))
	for _, app := range apps {
		listed[app.ID] = app.Version
		module, compiled := nexus.Get(app.ID)
		if !compiled {
			t.Errorf("каталог %s-ийг санал болгож байна, энэ бинарт түүний модуль алга", app.ID)
			continue
		}
		if module.Version() != app.Version {
			t.Errorf("%s нь %s хувилбараар компайл хийгдсэн, каталог %s гэж байна",
				app.ID, module.Version(), app.Version)
		}
		if module.Version() != app.Manifest.Version {
			t.Errorf("%s нь %s хувилбараар компайл хийгдсэн, манифест нь %s гэж байна",
				app.ID, module.Version(), app.Manifest.Version)
		}
	}

	for _, module := range ours {
		if _, found := listed[module.ID()]; !found {
			t.Errorf("%s нь энэ бинарт компайл хийгдсэн, каталогийн нэг ч бичилт түүнийг санал болгохгүй "+
				"тул хэн ч суулгаж чадахгүй, бүртгүүлсэн маршрут бүр нь татгалзагдана", module.ID())
		}
	}
}
