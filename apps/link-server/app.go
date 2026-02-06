package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/jinyu74/test-go/shared/appinfo"
)

type App struct {
	ctx context.Context
}

func NewApp() *App {
	return &App{}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func (a *App) Greet(name string) string {
	cleaned := strings.TrimSpace(name)
	if cleaned == "" {
		cleaned = "World"
	}

	return fmt.Sprintf("%s, %s!", appinfo.GreetingPrefix(), cleaned)
}
