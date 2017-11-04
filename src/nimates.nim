## A PostMates client written in Nim

import cgi
import base64
import httpclient
import json
import os, ospaths
import parsecfg
import tables
import strutils
import sequtils

proc encodeAllUrls(urls: varargs[string]): seq[string] =
  result = urls.map(encodeUrl)

proc `[]`(self: Config, value: string): string =
  result = self.getSectionValue("", value)

type
  PostMates* = ref object
    cid: string
    key: string
    quote: JsonNode
    config: Config
    client: HttpClient

method creds(self: PostMates) =
  if not fileExists(".credentials"):
    quit self.config["creds-error"]
  let
    jsonString = readFile(".credentials")
    json = parseJson(jsonString)
  self.cid = json{"customer_id"}.getStr
  self.key = json{"key"}.getStr

method croak(self: PostMates, err="last") =
  raise newException(Exception, self.config["$1-error" % err])

method initRequest(self: PostMates) =
  self.client = newHttpClient()
  let encoded: string = encode("$1:" % self.key)
  let auth = "Basic " & encoded
  self.client.headers = newHttpHeaders({
    "Content-Type"  : self.config["content-type"],
    "Accept-Type"   : self.config["accept-type"],
    "Authorization" : auth
  })

method request(self: PostMates, req: JsonNode): JsonNode =
  self.initRequest
  if req{"data"} == nil:
    req{"data"} = newJString("")
  let
    path       = req{"path"}.getStr
    httpMethod = req{"method"}.getStr "get"
    body       = req{"data"}.getStr
    url        = self.config["base"] & path
  echo self.config["request-log"] % [httpMethod, url, body]
  let resp: Response = self.client.request(
    url, httpMethod=httpMethod, body=body)
  if resp.status == "429":
    quit self.config["rate-error"]
  result = parseJson(resp.body)

method repr*(self: PostMates): string =
  ## Currently only outputs the base url of
  ## the PostMates API
  result = self.config["base"]

method estimate*(self: PostMates, pickup, dropoff: string): JsonNode =
  ## Returns an estimate (quote) for a potential
  ## delivery as json. Quotes can only be used
  ## once and are only valid for a limited duration
  let
    path = self.config["estimate"]
    data = self.config["estimate-data"]
    req: JsonNode = %* {
      "method": "post",
      "path": path % self.cid,
      "data": data % [pickup, dropoff].encodeAllUrls
    }
  self.quote = self.request req
  if self.quote["kind"].getStr == "error":
    self.croak
  self.quote["pickup_address"]  = newJString(pickup)
  self.quote["dropoff_address"] = newJString(dropoff)
  result = self.quote

method deliver*(self: PostMates, manifest, pickup_name, dropoff_name,
                pickup_phone_number, dropoff_phone_number,
                pickup_business_name="", dropoff_business_name="",
                pickup_notes="", dropoff_notes="",
                requires_id="false"): JsonNode =
  ## Creates a delivery for the items specified in the `manifest`.
  ## The items will be picked up from `pickup_name` and delivered
  ## to `dropoff_name`. If contact is required, either `dropoff_phone_number`
  ## or `pickup_phone_number` will be used. Any additional information
  ## can be specified via `pickup_notes` or `dropoff_notes`. The `quote_id`,
  ## `pickup_address`, and `dropoff_address` from the previously
  ## requested quote. If a quote is not made before a delivery is
  ## requested, an error will be raised.
  if self.quote == nil:
    self.croak("quote")
  let
    path = self.config["deliver"]
    data = self.config["deliver-data"].splitLines().join()
    req: JsonNode = %* {
      "method": "post",
      "path": path % self.cid,
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

method cancel*(self: PostMates, delivery_id: string): JsonNode =
  ## Cancel a delivery by its ID
  let
    path = self.config["cancel"]
    req: JsonNode = %* {
      "method": "post",
      "path": path % [
        self.cid,
        delivery_id
      ]
    }
  result = self.request req

method tip*(self: PostMates, delivery_id: string): JsonNode =
  ## Tip a delivery by its ID
  let
    path = self.config["tip"]
    req: JsonNode = %* {
      "method": "post",
      "path": path % [
        self.cid,
        delivery_id
      ]
    }
  result = self.request req

method zones*(self: PostMates): JsonNode =
  ## Get a GEOJson list of available zones
  let
    path = self.config["zones"]
    req: JsonNode = %* {
      "path": path
    }
  result = self.request req

method deliveries*(self: PostMates): JsonNode =
  ## Get a list of all deliveries ever made
  let
    path = self.config["deliveries"]
    req: JsonNode = %* {
      "path": path % self.cid
    }
  result = self.request req

method delivery*(self: PostMates, delivery_id: string): JsonNode =
  ## Get a delivery by its ID
  let
    path = self.config["delivery"]
    req: JsonNode = %* {
      "path": path % [
        self.cid,
        delivery_id
      ]
    }
  result = self.request req

proc newPostMates*(): PostMates =
  # `PostMates` constructor
  let
    confpath = "/config/default.ini"
    srcdir   = parentDir(currentSourcePath)
    config   = loadConfig(srcdir & confpath)
  result = PostMates(config : config)
  result.creds
