import base64
import httpclient
import json
import os
import tables
import strutils


proc readJson(): JsonNode =
  if not fileExists(".credentials"):
    quit "error: .credentials file not found"
  let jsonString: string = readFile(".credentials")
  return parseJson(jsonString)


type PostMates = ref object
  # credential properties
  config: JsonNode
  # client properties
  base: string
  client: HttpClient

method repr(self: PostMates): string {.base.} =
  return self.base

method initRequest(self: PostMates) {.base.} =
  self.client = newHttpClient()
  let encoded: string = encode("$1:" % self.config{"key"}.getStr)
  let auth = "Basic " & encoded
  self.client.headers = newHttpHeaders({
    "Content-Type": "application/x-www-form-urlencoded",
    "Return-Type": "application/json",
    "Authorization": auth
  })

method request(self: PostMates, req: JsonNode): JsonNode {.base.} =
  self.initRequest
  let path: string = req{"path"}.getStr
  let resp: Response = self.client.request(self.base & path, req{"method"}.getStr "get")
  if resp.status == "429":
    quit "error: rate limit exceeded"
  echo "[info] - $1 - $2" % [path, resp.status]
  let body: JsonNode = parseJson(resp.body)
  return body

# POSTS

method quote(self: PostMates, pickup, dropoff: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/delivery_quotes" % self.config{"customer_id"}.getStr,
    "data": %* {
      "pickup_address": pickup,
      "dropoff_address": dropoff
    }
  }
  return self.request req

method deliver(self: PostMates,
               quote_id,
               manifest,
               pickup_name,
               pickup_address,
               pickup_phone_number,
               pickup_business_name,
               pickup_notes,
               dropoff_name,
               dropoff_address,
               dropoff_phone_number,
               dropoff_business_name,
               dropoff_notes,
               requires_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/delivery_quotes" % self.config{"customer_id"}.getStr,
    "data": %* {
       "quote_id": quote_id,
       "manifest": manifest,
       "pickup_name": pickup_name,
       "pickup_address": pickup_address,
       "pickup_phone_number": pickup_phone_number,
       "pickup_business_name": pickup_business_name,
       "pickup_notes": pickup_notes,
       "dropoff_name": dropoff_name,
       "dropoff_address": dropoff_address,
       "dropoff_phone_number": dropoff_phone_number,
       "dropoff_business_name": dropoff_business_name,
       "dropoff_notes": dropoff_notes,
       "requires_id": requires_id
    }
  }
  return self.request req

method cancel(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/deliveries/$2/cancel" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  return self.request req

method tip(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/deliveries/$2" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  return self.request req

# GETS

method zones(self: PostMates): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/delivery_zones"
  }
  return self.request req

method deliveries(self: PostMates): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/customers/$1/deliveries" % self.config{"customer_id"}.getStr
  }
  return self.request req

method delivery(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/customers/$1/deliveries/$2" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  return self.request req

proc newPostMates(): PostMates =
  let config: JsonNode = readJson()
  return PostMates(base: "https://api.postmates.com/v1",
                   config: config)


var pm: PostMates = newPostMates()
echo pm.deliveries
# echo pm.quote("2306", "2307")


# method bytes(self: Assembler) {.base.} =
#   let binFile: File = open(self.filename)
#   let length: int64 = getFileSize(binFile)
#   self.binSeq = newSeq[uint8](length)
#   discard readBytes(binFile, self.binSeq, 0, length)
#   close(binFile)
