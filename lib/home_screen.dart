import 'dart:async';
import 'package:flutter/material.dart';
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
  List<LatLng> polyLinePoints = [];
  LatLng? destinationLatLng;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
              mapType: MapType.normal,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              myLocationEnabled: true,
              markers: _markers,
              polylines: _polyLines,
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

  Future<void> _getCurrentLocation() async {
    final isGranted = await _isLocationPermissionGranted();
    if (isGranted) {
      final isServiceEnabled = await _checkGpsServiceEnable();
      if (isServiceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your Location Is Detected'),
            duration: Duration(seconds: 3),
          ),
        );
        Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        )).listen((Position position) {
          setState(() {
            this.position = position;
            _addMarker(LatLng(position.latitude, position.longitude));
            updatePolyline(LatLng(position.latitude, position.longitude));
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
  void updatePolyline(LatLng currentPoint) {
    polyLinePoints.add(currentPoint);
    _polyLines.clear();
    _polyLines.add(
      Polyline(
        polylineId: const PolylineId('location-history'),
        points: polyLinePoints,
        color: Colors.blue,
        width: 4,
      ),
    );
  }

  void _addMarker(LatLng latLng) {
    _markers.clear();
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
