import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

const kGoogleApiKey = "AIzaSyCtHNT8If57yGm8IzD_WBrkbKnv0gBF6cg";

class SelectLocationPage extends StatefulWidget {
  @override
  _SelectLocationPageState createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  LatLng _initialPosition = const LatLng(40.65747, -7.91407);
  GoogleMapController? mapController;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _handleTap(LatLng tappedPoint) {
    setState(() {
      _initialPosition = tappedPoint;
    });
  }

  Future<void> _searchPlace(BuildContext context) async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: Mode.overlay,
      language: "pt",
      components: [Component(Component.country, "pt")],
    );

    if (p != null) {
      GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId!);
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;
      setState(() {
        _initialPosition = LatLng(lat, lng);
        mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione a Localização'),
        backgroundColor: Colors.blue,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 15,
        ),
        onTap: _handleTap,
        markers: {
          Marker(
            markerId: const MarkerId('selected-location'),
            position: _initialPosition,
          ),
        },
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 21.0, bottom: 16.0),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.pop(context, _initialPosition);
            },
            child: const Icon(Icons.check),
          ),
        ),
      ),
    );
  }
}