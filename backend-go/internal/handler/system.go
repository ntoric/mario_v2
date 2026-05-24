package handler

import (
	"net/http"
	"strconv"

	"cafe-backend/internal/middleware"
	"cafe-backend/internal/models"
	"cafe-backend/internal/repository"
)

// SystemReset handles POST /api/system/reset
func (h *Handler) SystemReset(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	if claims.Role != "superadmin" {
		h.writeError(w, http.StatusForbidden, "Only superadmin can perform system reset")
		return
	}

	var req models.SystemResetRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	params := repository.ResetParams{
		Users:      req.Users,
		Stores:     req.Stores,
		Categories: req.Categories,
		Items:      req.Items,
		Orders:     req.Orders,
		Tables:     req.Tables,
		Bills:      req.Bills,
	}

	results, err := h.Repo.System.Reset(r.Context(), params)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]interface{}{
		"message":      "System reset completed successfully",
		"resetResults": results,
	})
}

// GetStats handles GET /api/system/stats
func (h *Handler) GetStats(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	if claims.Role != "superadmin" {
		h.writeError(w, http.StatusForbidden, "Access denied")
		return
	}

	stats, err := h.Repo.System.GetStats(r.Context())
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, stats)
}

// GetSystemConfig handles GET /api/system/config
func (h *Handler) GetSystemConfig(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	if claims.Role != "superadmin" {
		h.writeError(w, http.StatusForbidden, "Access denied. Superadmin role required.")
		return
	}

	settings, err := h.Repo.System.GetConfig(r.Context())
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	enabled := settings["cleanup_enabled"] == "true"
	intervalMins, _ := strconv.Atoi(settings["cleanup_interval_mins"])
	if intervalMins <= 0 {
		intervalMins = 60
	}

	var lastRun *string
	if val, ok := settings["cleanup_last_run"]; ok && val != "" {
		lastRun = &val
	}

	h.writeJSON(w, http.StatusOK, models.SystemConfigResponse{
		CleanupEnabled:      enabled,
		CleanupIntervalMins: intervalMins,
		CleanupLastRun:      lastRun,
	})
}

// UpdateSystemConfig handles POST /api/system/config
func (h *Handler) UpdateSystemConfig(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	if claims.Role != "superadmin" {
		h.writeError(w, http.StatusForbidden, "Access denied. Superadmin role required.")
		return
	}

	var req models.SystemConfigRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if req.CleanupIntervalMins <= 0 {
		h.writeError(w, http.StatusBadRequest, "cleanupIntervalMins must be a positive integer greater than 0")
		return
	}

	err := h.Repo.System.SaveConfig(r.Context(), req.CleanupEnabled, req.CleanupIntervalMins)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]interface{}{
		"message": "System configuration updated successfully",
		"config": map[string]interface{}{
			"cleanupEnabled":      req.CleanupEnabled,
			"cleanupIntervalMins": req.CleanupIntervalMins,
		},
	})
}

