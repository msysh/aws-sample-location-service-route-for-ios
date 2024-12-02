//
//  ContentView.swift
//  AmazonLocationServiceRouteDemo
//
//  Created by msysh on 2024/12/01.
//

import SwiftUI
import CoreLocation
import MapLibre

import AmazonLocationiOSAuthSDK
import AWSGeoRoutes

struct ContentView: View {
    
    @State var route: [CLLocationCoordinate2D]?
    @State var isNoRoute: Bool = false
    
    var body: some View {
        MapView(route: $route)
            .edgesIgnoringSafeArea(.all)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            let origin = [136.884117, 35.170849]
                            let destination = [135.758783, 34.984068]
                            route = await getRoute(origin: origin, destination: destination)
                            isNoRoute = (route == nil || route!.isEmpty)
                        }
                    } label: {
                        Label("Route", systemImage: "truck.box")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical)
                    .alert("No route found", isPresented: $isNoRoute){
                    } message: {
                        Text("Maybe invalid origin or destination. Need to specify points on the road.")
                    }
                    Spacer()
                }
                .labelStyle(.iconOnly)
                .background(.thinMaterial)
            }
    }
}

struct MapView: UIViewRepresentable {
    
    let region: String = Bundle.main.object(forInfoDictionaryKey: "AmazonLocationServiceRegion") as! String
    let style: String = Bundle.main.object(forInfoDictionaryKey: "AmazonLocationServiceMapStyle") as! String
    let apiKey: String = Bundle.main.object(forInfoDictionaryKey: "AmazonLocationServiceApiKey") as! String
    
    @Binding var route: [CLLocationCoordinate2D]?
    
    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = URL(string: "https://maps.geo.\(region).amazonaws.com/v2/styles/\(style)/descriptor?color-scheme=Dark&key=\(apiKey)")!
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.setZoomLevel(11, animated: false)
        mapView.centerCoordinate = CLLocationCoordinate2D(latitude: 35.170099, longitude: 136.880507)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        guard let unwrappedRoute = route, !unwrappedRoute.isEmpty else {
            return
        }
                
        if let existingAnnotations = uiView.annotations {
            uiView.removeAnnotations(existingAnnotations)
        }
        
        let polyline = MLNPolyline(coordinates: unwrappedRoute, count: UInt(unwrappedRoute.count))
        uiView.addAnnotation(polyline)
    }
}

func getRoute(origin: [Double], destination: [Double]) async -> [CLLocationCoordinate2D] {
    let cognitoIdentityPoolId = Bundle.main.object(forInfoDictionaryKey: "AmazonCognitoIdentityPoolId") as! String
    let task = Task {
        do {
            let authHelper = try await AuthHelper.withIdentityPoolId(identityPoolId: cognitoIdentityPoolId)
            let client = GeoRoutesClient(config: authHelper.getGeoRoutesClientConfig())
            
            let travelModeOptions = GeoRoutesClientTypes.RouteTravelModeOptions(
                truck: GeoRoutesClientTypes.RouteTruckOptions(
                    axleCount: 4,
                    engineType: .internalCombustion,
                    grossWeight: 10000,
                    hazardousCargos: [ .gas ],
                    height: 2800,
                    length: 1200,
                    maxSpeed: 80,
                    occupancy: 2,
                    payloadCapacity: 9000,
                    tireCount: 8,
                    truckType: .straightTruck,
                    width: 250
                )
            )
    
            let input = AWSGeoRoutes.CalculateRoutesInput(
                avoid: GeoRoutesClientTypes.RouteAvoidanceOptions(tollRoads: true, tunnels: true),
                destination: destination,
                legGeometryFormat: .simple,
                origin: origin,
                travelMode: .truck,
                travelModeOptions: travelModeOptions
            )
            
            let output = try await client.calculateRoutes(input: input)
            var routePoints: [CLLocationCoordinate2D] = []
            output.routes?.forEach { route in
                route.legs?.forEach { leg in
                    leg.geometry?.lineString?.forEach { point in
                        routePoints.append(CLLocationCoordinate2D(latitude: point[1], longitude: point[0]))
                    }
                }
            }
            return routePoints
        } catch {
            print(error.localizedDescription)
        }
        return []
    }

    return await task.value
}

#Preview {
    ContentView()
}

