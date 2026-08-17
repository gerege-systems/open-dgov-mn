/*
 * Цахим Засаг — open.dgov.mn
 * Copyright (c) 2026 Gerege Systems Development Team, Gerege Nomadica Foundation.
 * Distributed under the Apache 2.0 License.
 */

// Command opendgov нь энэ байрлуулалтын сервер: Gerege Nexus цөм, түүний
// төрийн үйлчилгээний модулиуд (egov, documents, organisation, reports,
// urtuu — тэдгээр нь цөмд байгаа тул энд нэрлэгдэхгүй), дээр нь энэ репогийн
// өөрийн модулиуд.
//
// Цөмийн кодоос энд нэг ч мөр байхгүй: go.mod-ын нэг мөр л байна
// (docs/ECOSYSTEM_GIT_STRATEGY.md §1, Түвшин 2). Цөм шинэчлэгдэх нь тэр мөрийг
// хөдөлгөх ажил, хуулбар нийлүүлэх ажил биш.
//
// Энэ файлд өөр юу ч байх ёсгүй. Модулийн оронд энд бичигдсэн логик бол өөр
// байрлуулалт авч чадахгүй, тест хүрч чадахгүй логик — §5 дүрэм 3.
package main

import (
	"log/slog"
	"os"

	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/nexus"
	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/platform"

	"github.com/gerege-systems/open-dgov-mn/modules/zarlal"
)

func main() {
	err := platform.Run(platform.Options{
		Modules: func(p nexus.Platform) {
			zarlal.New(p)
		},
	})
	if err != nil {
		slog.Error("open.dgov.mn зогслоо", "error", err)
		os.Exit(1)
	}
}
