import json
import math


earthRadius = 20890700.0

class clockCoordinate:
	def __init__(self,hour,minute,distance):
		self.hour=int(hour or 0)
		self.minute=int(minute or 0)
		self.distance=float(distance or 0)

class geoCoordinate:
	def __init__(self,lat,lon):
		self.lat = float(lat)
		self.lon = float(lon)

	def __str__(self):
		return str(self.lat)+"	"+str(self.lon)

class art:
	def __init__(self,dict):
		self.name = dict.get('name','')
		hour = dict.get('hour', 0)
		minute = dict.get('minute', 0)
		distance = dict.get('distance', 0)

		self.clockCoordinate = clockCoordinate(hour,minute,distance)

	def jsonDic(self):
		dic = {}
		dic['name']=self.name
		dic["hour"]=self.clockCoordinate.hour
		dic["minute"]=self.clockCoordinate.minute
		dic["distance"]=self.clockCoordinate.distance
		dic["latitude"]=self.coordinates.lat
		dic["longitude"]=self.coordinates.lon
		return dic

class convert:
	def hourMinuteToDegrees(self,hour,minute):
		return .5*(60*(int(hour)%12)+int(minute))

	def bearing(self,hour,minute):
		return math.radians((self.hourMinuteToDegrees(hour,minute)+45)%360)

	#NOT USED
	def xDifference(self,clockCoordinate):
		angle = math.radians(self.hourMinuteToDegrees(clockCoordinate.hour,clockCoordinate.minute))
		return math.sin(angle)*clockCoordinate.distance

	#NOT USED
	def yDifference(self,clockCoordinate):
		angle = math.radians(self.hourMinuteToDegrees(clockCoordinate.hour,clockCoordinate.minute))
		return math.cos(angle)*clockCoordinate.distance

	def newCoordinate(self,center,cCoordinate):
		bearingAngle = self.bearing(cCoordinate.hour,cCoordinate.minute)	
		lat1= math.radians(center.lat)
		lon1= math.radians(center.lon)
		d = cCoordinate.distance

		lat2 = math.asin(math.sin(lat1)*math.cos(d/earthRadius)+math.cos(lat1)*math.sin(d/earthRadius)*math.cos(bearingAngle))
		lon2 = lon1+math.atan2(math.sin(bearingAngle)*math.sin(d/earthRadius)*math.cos(lat1), math.cos(d/earthRadius)-math.sin(lat1)*math.sin(lat2))
		return geoCoordinate(math.degrees(lat2),math.degrees(lon2))


if __name__ == '__main__':
	center = geoCoordinate(40.78700,-119.20430)
	converter = convert()
	clock = open("art-clock-locations.json","r")
	coordinateArray = json.loads(clock.read())
	finalArray = []
	
	for item in coordinateArray:
		item = art(item)
		item.coordinates = converter.newCoordinate(center,item.clockCoordinate)
		finalArray.append(item.jsonDic())

	#print json.dumps(coordinateArray)

	finalOutput = open("art-clock-loacatoins-lat-lon.json","w")
	finalOutput.write(json.dumps(finalArray,sort_keys=True, indent=4))
	finalOutput.close()
	clock.close()

#	cCoordinate = clockCoordinate(10,31,1000)	
#	converter = convert()
#	print converter.bearing(10,30)
#	print "X: "+str(converter.xDifference(cCoordinate))
#	print "Y: "+str(converter.yDifference(cCoordinate))
#	newCoord = converter.newCoordinate(center,cCoordinate)
#	print newCoord



