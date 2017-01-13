use test;
db.restaurants.insert(
    [
        {"address": {"building": "1007", "coord": [-73.856077, 40.848447], "street": "Morris Park Ave", "zipcode": "10462"}, "borough": "Bronx", "cuisine": "Bakery", "grades": [{"date": {"date": 1393804800000}, "grade": "A", "score": 2}, {"date": {"date": 1378857600000}, "grade": "A", "score": 6}, {"date": {"date": 1358985600000}, "grade": "A", "score": 10}, {"date": {"date": 1322006400000}, "grade": "A", "score": 9}, {"date": {"date": 1299715200000}, "grade": "B", "score": 14}], "name": "Morris Park Bake Shop", "restaurant_id": "30075445"},
        {"address": {"building": "469", "coord": [-73.961704, 40.662942], "street": "Flatbush Avenue", "zipcode": "11225"}, "borough": "Brooklyn", "cuisine": "Hamburgers", "grades": [{"date": {"date": 1419897600000}, "grade": "A", "score": 8}, {"date": {"date": 1404172800000}, "grade": "B", "score": 23}, {"date": {"date": 1367280000000}, "grade": "A", "score": 12}, {"date": {"date": 1336435200000}, "grade": "A", "score": 12}], "name": "Wendy'S", "restaurant_id": "30112340"},
        {"address": {"building": "351", "coord": [-73.98513559999999, 40.7676919], "street": "West   57 Street", "zipcode": "10019"}, "borough": "Manhattan", "cuisine": "Irish", "grades": [{"date": {"date": 1409961600000}, "grade": "A", "score": 2}, {"date": {"date": 1374451200000}, "grade": "A", "score": 11}, {"date": {"date": 1343692800000}, "grade": "A", "score": 12}, {"date": {"date": 1325116800000}, "grade": "A", "score": 12}], "name": "Dj Reynolds Pub And Restaurant", "restaurant_id": "30191841"}
    ]
);
