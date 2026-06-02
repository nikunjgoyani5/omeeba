# StoreKit 2 Receipt Validation Issue

## Problem

The backend is receiving error `21002: Invalid receipt data` when validating iOS purchases. This is because:

1. **StoreKit 2 uses JWT tokens** for transaction receipts (not base64 receipts)
2. **The backend is using the old receipt validation API** which expects base64-encoded receipt data
3. **JWT tokens cannot be validated** using the old receipt validation endpoint

## Receipt Format Detection

The app now sends a `receiptFormat` field to help the backend identify the format:
- `"JWT"` - StoreKit 2 JWT token (starts with `eyJ`)
- `"Base64"` - StoreKit 1 base64 receipt

## Backend Solution

The backend needs to handle **StoreKit 2 JWT tokens** using Apple's **App Store Server API**, not the old receipt validation API.

### Option 1: Use App Store Server API (Recommended)

For JWT tokens, use Apple's App Store Server API:

**Endpoint:** `https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}`

**Or verify JWT directly:**
- Decode the JWT token
- Verify the signature using Apple's public keys
- Extract transaction information from the payload

**Node.js Example:**
```javascript
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Decode JWT without verification first to get header
const decoded = jwt.decode(receiptData, { complete: true });
const kid = decoded.header.kid;

// Get Apple's public key
const client = jwksClient({
  jwksUri: 'https://api.storekit.itunes.apple.com/.well-known/jwks'
});

client.getSigningKey(kid, (err, key) => {
  if (err) {
    // Handle error
    return;
  }
  
  // Verify JWT
  const verified = jwt.verify(receiptData, key.getPublicKey(), {
    algorithms: ['ES256']
  });
  
  // Extract transaction info
  const transactionId = verified.transactionId;
  const productId = verified.productId;
  const purchaseDate = verified.purchaseDate;
  // ... etc
});
```

### Option 2: Update Backend to Handle Both Formats

```javascript
async function verifyApplePurchase(receiptData, productId, receiptFormat) {
  if (receiptFormat === 'JWT') {
    // Use App Store Server API for StoreKit 2
    return await verifyStoreKit2Receipt(receiptData, productId);
  } else {
    // Use old receipt validation API for StoreKit 1
    return await verifyStoreKit1Receipt(receiptData, productId);
  }
}
```

## Receipt Data Structure

### StoreKit 2 JWT Token (Current Format)

The JWT token contains:
- **Header**: Algorithm and key ID
- **Payload**: Transaction information
  - `transactionId`: Unique transaction ID
  - `originalTransactionId`: Original purchase transaction ID
  - `productId`: Product identifier (e.g., `omeeba_weekly_subscription`)
  - `purchaseDate`: Purchase timestamp
  - `expiresDate`: Expiration timestamp (for subscriptions)
  - `environment`: `Sandbox` or `Production`
  - `type`: `Auto-Renewable Subscription`
  - And more...

### StoreKit 1 Base64 Receipt (Legacy Format)

Base64-encoded receipt that needs to be sent to:
- **Sandbox**: `https://sandbox.itunes.apple.com/verifyReceipt`
- **Production**: `https://buy.itunes.apple.com/verifyReceipt`

## Current API Request Format

```json
{
  "receiptData": "eyJhbGciOiJFUzI1NiIs...",  // JWT token for StoreKit 2
  "productId": "omeeba_weekly_subscription",
  "receiptFormat": "JWT"  // New field to help backend
}
```

## Backend Implementation Steps

1. **Check `receiptFormat` field** in the request
2. **If `receiptFormat === "JWT"`**:
   - Use App Store Server API or JWT verification
   - Extract transaction info from JWT payload
   - Verify signature using Apple's public keys
3. **If `receiptFormat === "Base64"`**:
   - Use old receipt validation API
   - Send to Apple's verifyReceipt endpoint

## Apple Documentation

- **App Store Server API**: https://developer.apple.com/documentation/appstoreserverapi
- **JWT Verification**: https://developer.apple.com/documentation/appstoreserverapi/verifying_transaction_signatures
- **Receipt Validation**: https://developer.apple.com/documentation/appstorereceipts/validating_receipts_with_the_app_store

## Testing

When testing in sandbox:
- Receipt data will be a JWT token
- `environment` field in JWT will be `"Sandbox"`
- Use sandbox App Store Server API endpoints

## Important Notes

- ⚠️ **StoreKit 2 is the default** for iOS 15+ apps
- ⚠️ **JWT tokens cannot be validated** using the old receipt validation API
- ⚠️ **Backend must support both formats** for compatibility
- ⚠️ **Error 21002** means the backend is trying to validate JWT as base64 receipt

## Quick Fix for Backend

Add this check in your backend:

```javascript
if (receiptData.startsWith('eyJ')) {
  // It's a JWT token - use App Store Server API
  // Don't send to old verifyReceipt endpoint
} else {
  // It's base64 receipt - use old verifyReceipt endpoint
}
```
