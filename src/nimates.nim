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

method get(self: Config, value: string, section=""): string =
  result = self.getSectionValue(section, value)

proc `[]`(self: Config, value: string): string =
  result = self.get(value)

type
  PostMates* = ref object
    # credentials
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

method repr*(self: PostMates): string =
  result = self.config["base"]

method croak(self: PostMates, err="last") =
  raise newException(Exception, self.config["$1-error" % err])
    # "[$1] - $2" % [$self.quote["code"], $self.quote["message"]])

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

# Post Requests

method estimate*(self: PostMates, pickup, dropoff: string): JsonNode =
  discard """
  quote(self, pickup, dropoff)
  pickup  - address to pickup the order
  dropoff - address to dropoff the order

  returns an estimate (quote) for a potential
  delivery as json. Quotes can only be used
  once and are only valid for a limited duration
  """
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
  if self.quote == nil:
    self.croak("quote")
  let
    path = self.config["deliver"]
    data = self.config["deliver-data"]
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

# Get Requests

method zones*(self: PostMates): JsonNode =
  let
    path = self.config["zones"]
    req: JsonNode = %* {
      "path": path
    }
  result = self.request req

method deliveries*(self: PostMates): JsonNode =
  let
    path = self.config["deliveries"]
    req: JsonNode = %* {
      "path": path % self.cid
    }
  result = self.request req

method delivery*(self: PostMates, delivery_id: string): JsonNode =
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
  let
    confpath = "/config/default.ini"
    srcdir   = parentDir(currentSourcePath)
    config   = loadConfig(srcdir & confpath)
  result = PostMates(config : config)
  result.creds
