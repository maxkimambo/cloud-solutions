package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"cloud.google.com/go/pubsub"
	log "k8s.io/klog/v2"
)

/**
* Creates a PubSub client
 */
func createClient(ctx context.Context, projectID string) (*pubsub.Client, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	log.Infof("Created client with projectID: %s", projectID)
	if err != nil {
		log.Errorf("Error creating client: %v", err)
		return nil, err
	}
	return client, nil
}

/**
* Checks if a subscription exists
 */
func checkSubscriptionExists(ctx context.Context, client *pubsub.Client, subID string) (bool, error) {
	sub := client.Subscription(subID)
	exists, err := sub.Exists(ctx)
	log.Infof("Checking subscription with subID: %s", subID)
	log.Infof("Subscription exists: %v", exists)
	if err != nil {
		log.Errorf("Error checking subscription: %v", err)
		return false, err
	}
	return exists, nil
}

/**
* Creates a pull subscription for a given PubSub topic
 */
func createSubscription(ctx context.Context, client *pubsub.Client, subID string, topicID string) (*pubsub.Subscription, error) {
	log.Infof("Creating subscription with subID: %s", subID)
	sub, err := client.CreateSubscription(ctx, subID, pubsub.SubscriptionConfig{
		Topic:       client.Topic(topicID),
		AckDeadline: 30 * time.Second,
	})

	if err != nil {
		log.Errorf("Error creating subscription: %v", err)
		return nil, err
	}
	return sub, nil
}

/**
*  Gets the subscription by id and returns a pointer to it.
 */
func getSubscription(ctx context.Context, client *pubsub.Client, subID string) (*pubsub.Subscription, error) {
	log.Infof("Getting subscription with subID: %s", subID)
	sub := client.Subscription(subID)
	if sub == nil {
		return nil, fmt.Errorf("subscription with id not found: %s", subID)
	}
	return sub, nil
}

/**
 * InitializeSubscription creates a pull subscription if it does not exist
 * and returns a pointer to the subscription
 */
func InitializeSubscription(ctx context.Context, client *pubsub.Client, projectID string, subID string, topicID string) (*pubsub.Subscription, error) {

	exists, err := checkSubscriptionExists(ctx, client, subID)
	if err != nil {
		return &pubsub.Subscription{}, err
	}

	if exists {
		log.Infof("Subscription already exists. Skip creation for subID: %s", subID)
		sub, err := getSubscription(ctx, client, subID)
		if err != nil {
			log.Errorf("Error getting subscription: %v", err)
			return &pubsub.Subscription{}, err
		}
		return sub, nil
	}

	sub, err := createSubscription(ctx, client, subID, topicID)
	if err != nil {
		return &pubsub.Subscription{}, err
	}
	log.Infof("Subscription created with subID: %s", subID)
	return sub, nil
}

/**
* Receive messages from a subscription
 */
func PullMessages(ctx context.Context, sub *pubsub.Subscription) error {

	cctx, cancel := context.WithCancel(ctx)
	defer cancel()

	outmode := os.Getenv("LOG_OUTPUT") // file or stdout 

	if outmode == "file" {
		f, err := getFile()
		if err != nil {
			log.Errorf("Error getting file: %v", err)
			return err
		}

		defer f.Close()

		errMsg := sub.Receive(cctx, func(ctx context.Context, msg *pubsub.Message) {

			errFile := write(f, msg)
			if errFile != nil {
				logErrorAndNack(msg, errFile)
			}
			msg.Ack()
		})
		if errMsg != nil {
			log.Errorf("Error receiving message: %v", err)
			return err
		}
	}

	// by default output to stdout
	errMsg := sub.Receive(cctx, func(ctx context.Context, msg *pubsub.Message) {
		log.Info(string(msg.Data))
		msg.Ack()
	})
	if errMsg != nil {
		log.Errorf("Error receiving message: %v", errMsg)
		return errMsg
	}
	return nil
}

func logErrorAndNack(msg *pubsub.Message, err error) {
	log.Errorf("Error parsing message: %v", err)
	msg.Nack()
}

func getFile() (*os.File, error) {

	logFilePath := os.Getenv("LOG_PATH")

	if logFilePath == "" {
		logFilePath = "/tmp/cloudlogging-exporter.log"
	}

	log.Infof("Log file path set to : %s", logFilePath)
	log.Infof("Configure fluentd to read from this file: %s", logFilePath)

	f, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

	if err != nil {
		log.Errorf("Error opening log file: %v", err)
		return nil, err
	}

	return f, nil
}

// write append the message to the log file
func write(f *os.File, msg *pubsub.Message) error {

	// append to end of file
	if _, err := f.WriteString(string(msg.Data) + "\n"); err != nil {
		log.Errorf("Error writing to file: %v", err)
		return err
	}
	log.Info(string(msg.Data))

	return nil
}

func checkvars(){
	log.Info("Checking environment variables")
	projectID := os.Getenv("PROJECT_ID")
	subID := os.Getenv("SUB_ID")
	topicID := os.Getenv("TOPIC_ID")
	LOG_OUTPUT := os.Getenv("LOG_OUTPUT")
	
	if projectID == "" || subID == "" || topicID == "" {
		log.Fatal("PROJECT_ID (gcp project), SUB_ID (subscription), and TOPIC_ID (pubsub Topic) environment variables are required.")
	}
	if LOG_OUTPUT != "file" && LOG_OUTPUT != "stdout" {
		log.Warning("LOG_OUTPUT environment variable must be set to 'file' or 'stdout'. Defaulting to 'stdout'")
	}
}

func main() {

	log.Info("Starting GCP Log exporter")

	checkvars()

	projectID := os.Getenv("PROJECT_ID")
	subID := os.Getenv("SUB_ID")
	topicID := os.Getenv("TOPIC_ID")

	ctx := context.Background()

	client, err := createClient(ctx, projectID)

	if err != nil {
		log.Errorf("Client creation failed: %v", err)
		return
	}

	sub, err := InitializeSubscription(ctx, client, projectID, subID, topicID)

	if err != nil {
		log.Errorf("Subscription initialization failed: %v", err)
		return
	}

	subErr := PullMessages(ctx, sub)
	if subErr != nil {
		log.Errorf("Error pulling messages: %v", subErr)
	}
}
