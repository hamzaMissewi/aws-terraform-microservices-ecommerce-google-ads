package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"google.golang.org/api/option"
	"google.golang.org/api/googleads"
)

type GoogleAdsConfig struct {
	ClientID      string `json:"client_id"`
	ClientSecret  string `json:"client_secret"`
	RefreshToken  string `json:"refresh_token"`
	DeveloperToken string `json:"developer_token"`
}

type CampaignMonitorEvent struct {
	Timestamp time.Time `json:"timestamp"`
	Environment string  `json:"environment"`
}

type CampaignAlert struct {
	CampaignID     string  `json:"campaign_id"`
	CampaignName   string  `json:"campaign_name"`
	Status         string  `json:"status"`
	Impressions    int64   `json:"impressions"`
	Clicks         int64   `json:"clicks"`
	Cost           float64 `json:"cost"`
	Conversions    int64   `json:"conversions"`
	CTR            float64 `json:"ctr"`
	CPC            float64 `json:"cpc"`
	ConversionRate float64 `json:"conversion_rate"`
	AlertType      string  `json:"alert_type"`
	Message        string  `json:"message"`
}

var (
	secretName   = os.Getenv("GOOGLE_ADS_SECRET_ARN")
	snsTopicARN  = os.Getenv("SNS_TOPIC_ARN")
	environment  = os.Getenv("ENVIRONMENT")
)

func main() {
	lambda.Start(HandleCampaignMonitor)
}

func HandleCampaignMonitor(ctx context.Context, event interface{}) error {
	log.Printf("Starting campaign monitoring for environment: %s", environment)

	// Load Google Ads configuration
	config, err := loadGoogleAdsConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load Google Ads config: %w", err)
	}

	// Initialize Google Ads client
	client, err := createGoogleAdsClient(config)
	if err != nil {
		return fmt.Errorf("failed to create Google Ads client: %w", err)
	}

	// Monitor campaigns
	alerts, err := monitorCampaigns(ctx, client)
	if err != nil {
		return fmt.Errorf("failed to monitor campaigns: %w", err)
	}

	// Send alerts if any
	if len(alerts) > 0 {
		if err := sendAlerts(ctx, alerts); err != nil {
			return fmt.Errorf("failed to send alerts: %w", err)
		}
		log.Printf("Sent %d campaign alerts", len(alerts))
	} else {
		log.Println("No campaign alerts generated")
	}

	log.Printf("Campaign monitoring completed successfully")
	return nil
}

func loadGoogleAdsConfig(ctx context.Context) (*GoogleAdsConfig, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	svc := secretsmanager.NewFromConfig(cfg)
	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretName),
	}

	result, err := svc.GetSecretValue(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve secret: %w", err)
	}

	var config GoogleAdsConfig
	if err := json.Unmarshal([]byte(*result.SecretString), &config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal secret: %w", err)
	}

	return &config, nil
}

func createGoogleAdsConfig(config *GoogleAdsConfig) []option.ClientOption {
	return []option.ClientOption{
		option.WithCredentialsFile(config),
		option.WithScopes(googleads.GoogleAdsScope),
	}
}

func createGoogleAdsClient(config *GoogleAdsConfig) (*googleads.Service, error) {
	ctx := context.Background()
	opts := createGoogleAdsConfig(config)
	
	srv, err := googleads.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create Google Ads service: %w", err)
	}

	return srv, nil
}

func monitorCampaigns(ctx context.Context, client *googleads.Service) ([]CampaignAlert, error) {
	var alerts []CampaignAlert

	// Get customer ID (you might want to store this in config or environment)
	customerID := os.Getenv("GOOGLE_ADS_CUSTOMER_ID")
	if customerID == "" {
		return nil, fmt.Errorf("GOOGLE_ADS_CUSTOMER_ID environment variable not set")
	}

	// Query campaigns from the last 24 hours
	query := fmt.Sprintf(`
		SELECT 
			campaign.id,
			campaign.name,
			campaign.status,
			metrics.impressions,
			metrics.clicks,
			metrics.cost_micros,
			metrics.conversions,
			metrics.ctr,
			metrics.average_cpc,
			metrics.conversion_rate
		FROM campaign
		WHERE 
			campaign.status != 'REMOVED'
			AND segments.date DURING LAST_7_DAYS
	`)

	req := &googleads.SearchGoogleAdsRequest{
		CustomerId: customerID,
		Query:      query,
	}

	resp, err := client.Search(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to search campaigns: %w", err)
	}

	for _, row := range resp.Results {
		campaign := row.Campaign
		metrics := row.Metrics

		// Convert micros to dollars
		cost := float64(metrics.CostMicros) / 1000000.0
		cpc := float64(metrics.AverageCpc) / 1000000.0

		// Generate alerts based on performance metrics
		alert := generateAlert(campaign, metrics, cost, cpc)
		if alert != nil {
			alerts = append(alerts, *alert)
		}
	}

	return alerts, nil
}

func generateAlert(campaign *googleads.Campaign, metrics *googleads.Metrics, cost, cpc float64) *CampaignAlert {
	// Low performance alert
	if metrics.Impressions > 1000 && metrics.Ctr < 0.5 {
		return &CampaignAlert{
			CampaignID:     fmt.Sprintf("%d", campaign.Id),
			CampaignName:   campaign.Name,
			Status:         campaign.Status.String(),
			Impressions:    metrics.Impressions,
			Clicks:         metrics.Clicks,
			Cost:           cost,
			Conversions:    metrics.Conversions,
			CTR:            metrics.Ctr,
			CPC:            cpc,
			ConversionRate: metrics.ConversionRate,
			AlertType:      "LOW_PERFORMANCE",
			Message:        fmt.Sprintf("Campaign '%s' has low CTR: %.2f%%", campaign.Name, metrics.Ctr*100),
		}
	}

	// High cost alert
	if cost > 100.0 && metrics.Conversions == 0 {
		return &CampaignAlert{
			CampaignID:     fmt.Sprintf("%d", campaign.Id),
			CampaignName:   campaign.Name,
			Status:         campaign.Status.String(),
			Impressions:    metrics.Impressions,
			Clicks:         metrics.Clicks,
			Cost:           cost,
			Conversions:    metrics.Conversions,
			CTR:            metrics.Ctr,
			CPC:            cpc,
			ConversionRate: metrics.ConversionRate,
			AlertType:      "HIGH_COST_NO_CONVERSIONS",
			Message:        fmt.Sprintf("Campaign '%s' has high cost ($%.2f) with no conversions", campaign.Name, cost),
		}
	}

	// High CPC alert
	if cpc > 5.0 {
		return &CampaignAlert{
			CampaignID:     fmt.Sprintf("%d", campaign.Id),
			CampaignName:   campaign.Name,
			Status:         campaign.Status.String(),
			Impressions:    metrics.Impressions,
			Clicks:         metrics.Clicks,
			Cost:           cost,
			Conversions:    metrics.Conversions,
			CTR:            metrics.Ctr,
			CPC:            cpc,
			ConversionRate: metrics.ConversionRate,
			AlertType:      "HIGH_CPC",
			Message:        fmt.Sprintf("Campaign '%s' has high CPC: $%.2f", campaign.Name, cpc),
		}
	}

	return nil
}

func sendAlerts(ctx context.Context, alerts []CampaignAlert) error {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load AWS config: %w", err)
	}

	svc := sns.NewFromConfig(cfg)

	for _, alert := range alerts {
		message, err := json.Marshal(alert)
		if err != nil {
			log.Printf("Failed to marshal alert: %v", err)
			continue
		}

		subject := fmt.Sprintf("Google Ads Alert: %s - %s", alert.AlertType, alert.CampaignName)

		input := &sns.PublishInput{
			Message:  aws.String(string(message)),
			Subject:  aws.String(subject),
			TopicArn: aws.String(snsTopicARN),
		}

		_, err = svc.Publish(ctx, input)
		if err != nil {
			log.Printf("Failed to publish alert: %v", err)
			continue
		}

		log.Printf("Sent alert for campaign: %s", alert.CampaignName)
	}

	return nil
}
