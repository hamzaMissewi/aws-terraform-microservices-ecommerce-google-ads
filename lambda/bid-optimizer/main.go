package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"google.golang.org/api/option"
	"google.golang.org/api/googleads"
)

type BidOptimizationEvent struct {
	Timestamp time.Time `json:"timestamp"`
	Environment string  `json:"environment"`
}

type BidOptimizationResult struct {
	CampaignID       string  `json:"campaign_id"`
	CampaignName     string  `json:"campaign_name"`
	AdGroupID        string  `json:"ad_group_id"`
	AdGroupName      string  `json:"ad_group_name"`
	KeywordID        string  `json:"keyword_id"`
	KeywordText      string  `json:"keyword_text"`
	CurrentBid       float64 `json:"current_bid"`
	RecommendedBid   float64 `json:"recommended_bid"`
	OptimizationType string  `json:"optimization_type"`
	Reason           string  `json:"reason"`
	ExpectedImpact   string  `json:"expected_impact"`
}

type GoogleAdsConfig struct {
	ClientID      string `json:"client_id"`
	ClientSecret  string `json:"client_secret"`
	RefreshToken  string `json:"refresh_token"`
	DeveloperToken string `json:"developer_token"`
}

var (
	secretName   = os.Getenv("GOOGLE_ADS_SECRET_ARN")
	snsTopicARN  = os.Getenv("SNS_TOPIC_ARN")
	environment  = os.Getenv("ENVIRONMENT")
)

func main() {
	lambda.Start(HandleBidOptimization)
}

func HandleBidOptimization(ctx context.Context, event interface{}) error {
	log.Printf("Starting bid optimization for environment: %s", environment)

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

	// Perform bid optimization
	results, err := optimizeBids(ctx, client)
	if err != nil {
		return fmt.Errorf("failed to optimize bids: %w", err)
	}

	// Send optimization results if any
	if len(results) > 0 {
		if err := sendOptimizationResults(ctx, results); err != nil {
			return fmt.Errorf("failed to send optimization results: %w", err)
		}
		log.Printf("Sent %d bid optimization recommendations", len(results))
	} else {
		log.Println("No bid optimizations recommended")
	}

	log.Printf("Bid optimization completed successfully")
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

func optimizeBids(ctx context.Context, client *googleads.Service) ([]BidOptimizationResult, error) {
	var results []BidOptimizationResult

	// Get customer ID
	customerID := os.Getenv("GOOGLE_ADS_CUSTOMER_ID")
	if customerID == "" {
		return nil, fmt.Errorf("GOOGLE_ADS_CUSTOMER_ID environment variable not set")
	}

	// Query keywords with performance data from last 14 days
	query := fmt.Sprintf(`
		SELECT 
			campaign.id,
			campaign.name,
			ad_group.id,
			ad_group.name,
			ad_group_criterion.criterion_id,
			ad_group_criterion.keyword.text,
			ad_group_criterion.keyword.match_type,
			metrics.impressions,
			metrics.clicks,
			metrics.cost_micros,
			metrics.conversions,
			metrics.ctr,
			metrics.average_cpc,
			metrics.conversion_rate,
			metrics.cost_per_conversion
		FROM keyword_view
		WHERE 
			ad_group_criterion.status = 'ENABLED'
			AND campaign.status = 'ENABLED'
			AND ad_group.status = 'ENABLED'
			AND segments.date DURING LAST_14_DAYS
			AND metrics.impressions > 50
	`)

	req := &googleads.SearchGoogleAdsRequest{
		CustomerId: customerID,
		Query:      query,
	}

	resp, err := client.Search(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to search keywords: %w", err)
	}

	for _, row := range resp.Results {
		campaign := row.Campaign
		adGroup := row.AdGroup
		keyword := row.AdGroupCriterion.Keyword
		metrics := row.Metrics

		// Convert micros to dollars
		cost := float64(metrics.CostMicros) / 1000000.0
		cpc := float64(metrics.AverageCpc) / 1000000.0
		costPerConversion := float64(metrics.CostPerConversion) / 1000000.0

		// Get current bid (this would require additional API call to get criterion data)
		currentBid := cpc // Simplified for example

		// Calculate recommended bid based on performance
		recommendedBid, optimizationType, reason := calculateRecommendedBid(
			metrics, currentBid, cost, costPerConversion,
		)

		// Only recommend if the change is significant (>20% difference)
		if math.Abs(recommendedBid-currentBid)/currentBid > 0.2 {
			result := BidOptimizationResult{
				CampaignID:       fmt.Sprintf("%d", campaign.Id),
				CampaignName:     campaign.Name,
				AdGroupID:        fmt.Sprintf("%d", adGroup.Id),
				AdGroupName:      adGroup.Name,
				KeywordID:        fmt.Sprintf("%d", row.AdGroupCriterion.CriterionId),
				KeywordText:      keyword.Text,
				CurrentBid:       currentBid,
				RecommendedBid:   recommendedBid,
				OptimizationType: optimizationType,
				Reason:           reason,
				ExpectedImpact:   calculateExpectedImpact(currentBid, recommendedBid, metrics),
			}
			results = append(results, result)
		}
	}

	return results, nil
}

func calculateRecommendedBid(metrics *googleads.Metrics, currentBid, cost, costPerConversion float64) (float64, string, string) {
	ctr := metrics.Ctr
	conversionRate := metrics.ConversionRate

	// High performing keywords - increase bid
	if ctr > 0.02 && conversionRate > 0.05 && costPerConversion < 50.0 {
		newBid := currentBid * 1.25 // Increase by 25%
		return newBid, "INCREASE_BID", fmt.Sprintf("High CTR (%.2f%%) and conversion rate (%.2f%%) with low cost per conversion ($%.2f)", ctr*100, conversionRate*100, costPerConversion)
	}

	// Low performing keywords - decrease bid
	if ctr < 0.005 && metrics.Impressions > 1000 {
		newBid := currentBid * 0.75 // Decrease by 25%
		return newBid, "DECREASE_BID", fmt.Sprintf("Low CTR (%.2f%%) despite high impressions (%d)", ctr*100, metrics.Impressions)
	}

	// High cost per conversion - decrease bid
	if costPerConversion > 100.0 && metrics.Conversions > 0 {
		newBid := currentBid * 0.8 // Decrease by 20%
		return newBid, "DECREASE_BID", fmt.Sprintf("High cost per conversion ($%.2f)", costPerConversion)
	}

	// Good performance with room for improvement - moderate increase
	if ctr > 0.01 && conversionRate > 0.02 && costPerConversion < 75.0 {
		newBid := currentBid * 1.15 // Increase by 15%
		return newBid, "MODERATE_INCREASE", fmt.Sprintf("Good performance metrics with room for growth")
	}

	// No change recommended
	return currentBid, "NO_CHANGE", "Performance metrics are within acceptable ranges"
}

func calculateExpectedImpact(currentBid, recommendedBid float64, metrics *googleads.Metrics) string {
	changePercent := ((recommendedBid - currentBid) / currentBid) * 100

	if changePercent > 0 {
		return fmt.Sprintf("Estimated %.0f%% increase in clicks and conversions", changePercent*0.8)
	} else {
		return fmt.Sprintf("Estimated %.0f%% cost reduction with minimal impact on conversions", math.Abs(changePercent))
	}
}

func sendOptimizationResults(ctx context.Context, results []BidOptimizationResult) error {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load AWS config: %w", err)
	}

	svc := sns.NewFromConfig(cfg)

	// Group results by optimization type for better organization
	groupedResults := make(map[string][]BidOptimizationResult)
	for _, result := range results {
		groupedResults[result.OptimizationType] = append(groupedResults[result.OptimizationType], result)
	}

	// Send summary message
	summary := map[string]interface{}{
		"timestamp":   time.Now(),
		"environment": environment,
		"total_recommendations": len(results),
		"optimization_summary": map[string]int{
			"INCREASE_BID":       len(groupedResults["INCREASE_BID"]),
			"DECREASE_BID":       len(groupedResults["DECREASE_BID"]),
			"MODERATE_INCREASE":  len(groupedResults["MODERATE_INCREASE"]),
		},
		"recommendations": results,
	}

	message, err := json.MarshalIndent(summary, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal summary: %w", err)
	}

	subject := fmt.Sprintf("Google Ads Bid Optimization Report - %d Recommendations", len(results))

	input := &sns.PublishInput{
		Message:  aws.String(string(message)),
		Subject:  aws.String(subject),
		TopicArn: aws.String(snsTopicARN),
	}

	_, err = svc.Publish(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to publish optimization results: %w", err)
	}

	log.Printf("Sent bid optimization summary with %d recommendations", len(results))
	return nil
}
