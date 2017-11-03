import cgi
import base64
import httpclient
import json
import os
import tables
import strutils
import sequtils


proc readJson(): JsonNode =
  if not fileExists(".credentials"):
    quit "error: .credentials file not found"
  let jsonString: string = readFile(".credentials")
  result = parseJson(jsonString)

proc encodeAllUrls(urls: varargs[string]): seq[string] =
  return urls.map(encodeUrl)

type
  PostMates* = ref object
    # credential properties
    config: JsonNode
    # client properties
    base: string
    quote: JsonNode
    client: HttpClient

method repr*(self: PostMates): string {.base.} =
  result = self.base

method initRequest(self: PostMates) {.base.} =
  self.client = newHttpClient()
  let encoded: string = encode("$1:" % self.config{"key"}.getStr)
  let auth = "Basic " & encoded
  self.client.headers = newHttpHeaders({
    "Content-Type": "application/x-www-form-urlencoded",
    "Accept-Type": "application/json",
    "Authorization": auth
  })

method request(self: PostMates, req: JsonNode): JsonNode {.base.} =
  self.initRequest
  if req{"data"} == nil:
    req{"data"} = newJString("")
  let
    path       = req{"path"}.getStr
    httpMethod = req{"method"}.getStr "get"
    body       = req{"data"}.getStr
    url        = self.base & path
  echo "method: $1\nurl: $2\nbody: $3" % [httpMethod, url, body]
  let resp: Response = self.client.request(
    url, httpMethod=httpMethod, body=body)
  if resp.status == "429":
    quit "error: rate limit exceeded"
  result = parseJson(resp.body)

# Post Requests

method estimate*(self: PostMates, pickup, dropoff: string): JsonNode {.base.} =
  discard """
  quote(self, pickup, dropoff)
  pickup  - address to pickup the order
  dropoff - address to dropoff the order

  returns an estimate (quote) for a potential
  delivery as json. Quotes can only be used
  once and are only valid for a limited duration
  """
  let
    path = "/customers/$1/delivery_quotes"
    data = "pickup_address=$1&dropoff_address=$2"
    req: JsonNode = %* {
      "method": "post",
      "path": path % self.config{"customer_id"}.getStr,
      "data": data % [pickup, dropoff].encodeAllUrls
    }
  self.quote = self.request req
  if self.quote["kind"].getStr == "error":
    raise newException(
      Exception,
      "[$1] - $2" % [$self.quote["code"], $self.quote["message"]])
  self.quote["pickup_address"]  = newJString(pickup)
  self.quote["dropoff_address"] = newJString(dropoff)
  result = self.quote

method deliver*(self: PostMates,
                manifest,
                pickup_name,
                pickup_phone_number,
                dropoff_name,
                dropoff_phone_number,
                pickup_business_name="",
                pickup_notes="",
                dropoff_business_name="",
                dropoff_notes="",
                requires_id="false"): JsonNode {.base.} =
  if self.quote == nil:
    raise newException(
      Exception,
      "must request a quote before a delivery can be made")
  let
    path = "/customers/$1/deliveries"
    data = "quote_id=$1&pickup_address=$2&dropoff_address=$3&manifest=$4&" &
           "pickup_name=$5&dropoff_name=$6&pickup_phone_number=$7&" &
           "dropoff_phone_number=$8&pickup_business_name=$9&" &
           "dropoff_business_name=$10&pickup_notes=$11&" &
           "dropoff_notes=$12&requires_id=$13"
    req: JsonNode = %* {
      "method": "post",
      "path": path % self.config{"customer_id"}.getStr,
      "data": data % [
        self.quote["id"].getStr,
        self.quote["pickup_address"].getStr,
        self.quote["dropoff_address"].getStr,
        manifest, pickup_name, dropoff_name,
        pickup_phone_number, dropoff_phone_number,
        pickup_business_name, dropoff_business_name,
        pickup_notes, dropoff_notes, requires_id
      ].encodeAllUrls
    }
  result = self.request req

method cancel*(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/deliveries/$2/cancel" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  result = self.request req

method tip*(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "method": "post",
    "path": "/customers/$1/deliveries/$2" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  result = self.request req

# GETS

method zones*(self: PostMates): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/delivery_zones"
  }
  result = self.request req

method deliveries*(self: PostMates): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/customers/$1/deliveries" % self.config{"customer_id"}.getStr
  }
  result = self.request req

method delivery*(self: PostMates, delivery_id: string): JsonNode {.base.} =
  let req: JsonNode = %* {
    "path": "/customers/$1/deliveries/$2" % [
      self.config{"customer_id"}.getStr,
      delivery_id
    ]
  }
  result = self.request req

proc newPostMates*(): PostMates =
  let config: JsonNode = readJson()
  result = PostMates(base: "https://api.postmates.com/v1",
                     config: config,
                     quote: nil)
