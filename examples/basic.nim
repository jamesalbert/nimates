import nimates
import json


var pm: PostMates = newPostMates()

var a: JsonNode = pm.estimate(
  pickup  = "1900 N Highland Ave",
  dropoff = "3000 N Cahuenga Blvd"
)
echo a
echo "estimated"

var b: JsonNode = pm.zones
echo b[0]{"properties"}

var c: JsonNode = pm.deliver(
  "A box of gray kittens",
  "Starbucks",
  "James Albert",
  "(555) 555-5555",
  "(666) 666-6666"
)
echo c
echo "delivered"

var d: JsonNode = pm.cancel(c["id"].getStr)
echo "canceled"

var e: JsonNode = pm.deliveries
echo e
