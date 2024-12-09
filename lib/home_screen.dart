import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? position;
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polyLines = {};
  LatLng? destinationLatLng;
  late StreamSubscription<Position> positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    positionStreamSubscription.cancel(); // Make sure to cancel the stream when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map'),
      ),
      body: position == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(position!.latitude, position!.longitude),
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        myLocationEnabled: true,
        markers: _markers,
        polylines: _polyLines,
        onTap: _onTapMap,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _getCurrentLocation();
          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: LatLng(position!.latitude, position!.longitude),
                  zoom: 15),
            ),
          );
        },
        child: const Icon(Icons.location_searching),
      ),
    );
  }

  void _onTapMap(LatLng currentLatLng) {
    setState(() {
      destinationLatLng = currentLatLng;
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: currentLatLng,
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: '${currentLatLng.latitude},${currentLatLng.longitude}',
          ),
        ),
      );
      _getPoliline();
    });
  }

  Future<void> _getPoliline() async {
    if (destinationLatLng == null || position == null) return;

    PolylinePoints points = PolylinePoints();
    PolylineResult result = await points.getRouteBetweenCoordinates(
      googleApiKey: 'YOUR_GOOGLE_MAPS_API_KEY',
      request: PolylineRequest(
          origin: PointLatLng(position!.latitude, position!.longitude),
          destination: PointLatLng(
            destinationLatLng!.latitude,
            destinationLatLng!.longitude,
          ),
          mode: TravelMode.driving),
    );
    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        _polyLines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: polylineCoordinates,
        ));
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final isGranted = await _isLocationPermissionGranted();
    if (isGranted) {
      final isServiceEnabled = await _checkGpsServiceEnable();
      if (isServiceEnabled) {
        // Start listening for location updates
        positionStreamSubscription = Geolocator.getPositionStream(
         locationSettings: const LocationSettings(
           accuracy: LocationAccuracy.high,
           timeLimit: Duration(seconds: 60),
         )
        ).listen((Position position) {
          setState(() {
            this.position = position;
            _updateLocation(position);
          });
        });
      } else {
        Geolocator.openLocationSettings();
      }
    } else {
      final result = await _requestPermission();
      if (result) {
        _getCurrentLocation();
      } else {
        Geolocator.openAppSettings();
      }
    }
  }

  void _updateLocation(Position position) {
    // Update the polyline based on the new location
    if (destinationLatLng != null) {
      _getPoliline();
    }
    // Add or update the marker for the current location
    _addMarker(LatLng(position.latitude, position.longitude));
  }

  void _addMarker(LatLng latLng) {
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'My Current Location:',
          snippet: '${latLng.latitude},${latLng.longitude}',
        ),
      ),
    );
  }

  Future<bool> _isLocationPermissionGranted() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> _requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> _checkGpsServiceEnable() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
