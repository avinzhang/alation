import requests
import json
import csv


base_url = "https://avin.alationproserv.com"
cf_url = base_url + "/integration/v2/custom_field/?limit=100&skip=0&field_type=RICH_TEXT"
singular_field_name = "Description"

payload = {}
headers = {
  'token': 'xxxxxxxxxxxxxxxx'
}
params_ds = {}
filename = 'file.csv'

response = requests.request("GET", cf_url, headers=headers, data=payload)
result_json = response.json()
for cf in result_json:
    if cf["name_singular"] == (singular_field_name):
        print("The custom field id is" , cf["id"])
        customfield_id = cf["id"]
        break


#update custom field
cfv_url = base_url + "/integration/v2/custom_field_value/"

with open(filename, 'r') as csvfile:
  datareader = csv.reader(csvfile)
  for row in datareader:
    payload = [
    {
      "field_id": customfield_id,
      "otype": "bi_report",
      "oid": row[0],
      "value": row[1]
    }
    ]
    #print '"' + str(variable) + '"'
    print("Updating Description custom field for BI report with id", row[0], "to", '"'+str(row[1])+'"')
    response = requests.put(cfv_url, json=payload, params=params_ds,headers=headers)
