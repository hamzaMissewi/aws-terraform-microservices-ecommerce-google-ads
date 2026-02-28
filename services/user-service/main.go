package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/gorilla/mux"
)

type User struct {
	ID        string    `json:"id" dynamodbav:"id"`
	Email     string    `json:"email" dynamodbav:"email"`
	FirstName string    `json:"first_name" dynamodbav:"first_name"`
	LastName  string    `json:"last_name" dynamodbav:"last_name"`
	CreatedAt time.Time `json:"created_at" dynamodbav:"created_at"`
	UpdatedAt time.Time `json:"updated_at" dynamodbav:"updated_at"`
}

type CreateUserRequest struct {
	Email     string `json:"email"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type UpdateUserRequest struct {
	FirstName *string `json:"first_name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
}

type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Service   string    `json:"service"`
	Version   string    `json:"version"`
}

var (
	dynamoClient *dynamodb.Client
	tableName    string
	serverPort   string
	version      = "1.0.0"
)

func main() {
	// Initialize AWS configuration
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("Failed to load AWS configuration: %v", err)
	}

	// Initialize DynamoDB client
	dynamoClient = dynamodb.NewFromConfig(cfg)
	tableName = getEnv("DYNAMODB_TABLE_NAME", "users")
	serverPort = getEnv("PORT", "3000")

	// Create router
	router := mux.NewRouter()

	// Health check endpoint
	router.HandleFunc("/health", healthCheckHandler).Methods("GET")

	// User endpoints
	router.HandleFunc("/users", createUserHandler).Methods("POST")
	router.HandleFunc("/users/{id}", getUserHandler).Methods("GET")
	router.HandleFunc("/users/{id}", updateUserHandler).Methods("PUT")
	router.HandleFunc("/users/{id}", deleteUserHandler).Methods("DELETE")
	router.HandleFunc("/users", listUsersHandler).Methods("GET")

	// Start server
	srv := &http.Server{
		Handler:      router,
		Addr:         ":" + serverPort,
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}

	log.Printf("User service starting on port %s", serverPort)
	log.Fatal(srv.ListenAndServe())
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Service:   "user-service",
		Version:   version,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func createUserHandler(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate input
	if req.Email == "" || req.FirstName == "" || req.LastName == "" {
		http.Error(w, "Missing required fields", http.StatusBadRequest)
		return
	}

	// Create user
	user := User{
		ID:        generateUUID(),
		Email:     req.Email,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Save to DynamoDB
	if err := saveUser(user); err != nil {
		log.Printf("Failed to save user: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(user)
}

func getUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["id"]

	user, err := getUserByID(userID)
	if err != nil {
		if err.Error() == "user not found" {
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}
		log.Printf("Failed to get user: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

func updateUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["id"]

	var req UpdateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Get existing user
	user, err := getUserByID(userID)
	if err != nil {
		if err.Error() == "user not found" {
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}
		log.Printf("Failed to get user: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Update fields
	if req.FirstName != nil {
		user.FirstName = *req.FirstName
	}
	if req.LastName != nil {
		user.LastName = *req.LastName
	}
	user.UpdatedAt = time.Now()

	// Save updated user
	if err := saveUser(user); err != nil {
		log.Printf("Failed to update user: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

func deleteUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["id"]

	if err := deleteUserByID(userID); err != nil {
		log.Printf("Failed to delete user: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "User deleted successfully"})
}

func listUsersHandler(w http.ResponseWriter, r *http.Request) {
	users, err := listAllUsers()
	if err != nil {
		log.Printf("Failed to list users: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"users": users})
}

// DynamoDB operations
func saveUser(user User) error {
	item, err := attributevalue.MarshalMap(user)
	if err != nil {
		return fmt.Errorf("failed to marshal user: %w", err)
	}

	_, err = dynamoClient.PutItem(context.TODO(), &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})

	return err
}

func getUserByID(userID string) (User, error) {
	result, err := dynamoClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]dynamodb.AttributeValue{
			"id": &dynamodb.AttributeMemberS{Value: userID},
		},
	})

	if err != nil {
		return User{}, fmt.Errorf("failed to get user: %w", err)
	}

	if len(result.Item) == 0 {
		return User{}, fmt.Errorf("user not found")
	}

	var user User
	err = attributevalue.UnmarshalMap(result.Item, &user)
	if err != nil {
		return User{}, fmt.Errorf("failed to unmarshal user: %w", err)
	}

	return user, nil
}

func deleteUserByID(userID string) error {
	_, err := dynamoClient.DeleteItem(context.TODO(), &dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key: map[string]dynamodb.AttributeValue{
			"id": &dynamodb.AttributeMemberS{Value: userID},
		},
	})

	return err
}

func listAllUsers() ([]User, error) {
	result, err := dynamoClient.Scan(context.TODO(), &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	})

	if err != nil {
		return nil, fmt.Errorf("failed to scan users: %w", err)
	}

	var users []User
	for _, item := range result.Items {
		var user User
		err := attributevalue.UnmarshalMap(item, &user)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal user: %w", err)
		}
		users = append(users, user)
	}

	return users, nil
}

// Utility functions
func generateUUID() string {
	// Simple UUID generation - in production, use a proper UUID library
	return fmt.Sprintf("%d", time.Now().UnixNano())
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
