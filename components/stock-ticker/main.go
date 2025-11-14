package main

import (
	"math"

	"go.bytecodealliance.org/cm"
	"stock-ticker/gen/stock/ticker/ticker"
)

// Base prices for each stock (realistic starting values)
var basePrices = map[ticker.StockSymbol]float64{
	ticker.StockSymbolMsft:  420.50, // Microsoft
	ticker.StockSymbolAapl:  185.75, // Apple
	ticker.StockSymbolGoogl: 142.30, // Google/Alphabet
	ticker.StockSymbolAmzn:  175.80, // Amazon
}

// Current prices (will fluctuate)
var currentPrices = make(map[ticker.StockSymbol]float64)

// Counter for simulating timestamps and randomness
var counter uint64

// Simple LCG random number generator (to avoid stdlib dependencies)
func nextRandom() float64 {
	counter = (counter*1103515245 + 12345) & 0x7fffffff
	return float64(counter) / float64(0x7fffffff)
}

func init() {
	// Initialize with a non-zero seed
	counter = 42

	// Initialize current prices with base prices
	for symbol, price := range basePrices {
		currentPrices[symbol] = price
	}

	// Set the exported functions
	ticker.Exports.GetPrice = getPrice
	ticker.Exports.GetAllPrices = getAllPrices
	ticker.Exports.Tick = tick
}

// getPrice returns the current price for a specific stock
func getPrice(symbol ticker.StockSymbol) ticker.StockPrice {
	price := getStockPrice(symbol)
	counter++
	return ticker.StockPrice{
		Symbol:    symbol,
		Price:     price,
		Timestamp: counter,
	}
}

// getAllPrices returns current prices for all stocks
func getAllPrices() cm.List[ticker.StockPrice] {
	prices := make([]ticker.StockPrice, 0, len(basePrices))
	counter++
	timestamp := counter

	// Iterate through all stock symbols
	for symbol := range basePrices {
		price := getStockPrice(symbol)
		prices = append(prices, ticker.StockPrice{
			Symbol:    symbol,
			Price:     price,
			Timestamp: timestamp,
		})
	}

	return cm.ToList(prices)
}

// tick simulates price updates and returns a batch
func tick(config ticker.TickerConfig) cm.List[ticker.StockPrice] {
	symbols := config.Symbols.Slice()
	prices := make([]ticker.StockPrice, 0, len(symbols))
	counter++
	timestamp := counter

	// Update prices for requested symbols
	for _, symbol := range symbols {
		// Simulate price movement
		updatePrice(symbol)
		price := getStockPrice(symbol)

		prices = append(prices, ticker.StockPrice{
			Symbol:    symbol,
			Price:     price,
			Timestamp: timestamp,
		})
	}

	return cm.ToList(prices)
}

// getStockPrice retrieves the current price for a symbol
func getStockPrice(symbol ticker.StockSymbol) float64 {
	if price, ok := currentPrices[symbol]; ok {
		return price
	}
	// Fallback to base price if not found
	if basePrice, ok := basePrices[symbol]; ok {
		currentPrices[symbol] = basePrice
		return basePrice
	}
	// Default fallback
	return 100.0
}

// updatePrice simulates realistic stock price movement
func updatePrice(symbol ticker.StockSymbol) {
	currentPrice := getStockPrice(symbol)

	// Generate a random price change
	// Random percentage change between -2% and +2%
	percentChange := (nextRandom() - 0.5) * 4.0

	// Apply the change
	newPrice := currentPrice * (1.0 + percentChange/100.0)

	// Ensure price doesn't go negative or unreasonably low
	basePrice := basePrices[symbol]
	minPrice := basePrice * 0.5 // Don't go below 50% of base
	maxPrice := basePrice * 1.5 // Don't go above 150% of base

	newPrice = math.Max(minPrice, math.Min(maxPrice, newPrice))

	// Round to 2 decimal places
	newPrice = math.Round(newPrice*100) / 100

	currentPrices[symbol] = newPrice
}

func main() {
	// Required for TinyGo WASI builds
}
