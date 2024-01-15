import h5py
import numpy as np
import networkx as nx
import pydot
import dataclasses
import json

from typing import List, Any, Dict

@dataclasses.dataclass(frozen=True)
class GeometricData:
    """
    GeometricData is a dataclass for easy conversion to
    the format that dgl accepts.

    See - https://docs.dgl.ai/guide/training-graph.html.

    The labels consist of an indegree and an outdegree.
    """
    edges: List[List[int]]
    labels: List[List[int]]
    num_nodes: int

    def to_json(self) -> Any:
        return json.dumps({ "edgelist": self.edges, "labels": self.labels, "num_nodes": self.num_nodes })

def get_vertex_map(vertices: List[str]) -> Dict[str, int]:
    """
    From a list of vertices, obtain a zero indexed mapping of
    vertices while maintaining the relationships between vertices.

    :param vertices: The vertices that the function accepts.
    :return: A dictionary containing a mapping of a string vertex to an integer.
    """
    idx = 0
    vertex_map = {}
    for v in vertices:
        vertex = vertex_map.get(v)
        if vertex is None:
            vertex_map[v] = idx
            idx += 1

    return vertex_map

def encode_edges(graph: nx.DiGraph) -> List[List[int]]:
    """
    From a graph, encode the edges in the graph such that the graph
    the edges are all 0 indexed.

    :param graph: A directed graph.
    :return: A list of encoded edges.
    """
    vertex_map = get_vertex_map(graph.nodes)
    return [[vertex_map[a], vertex_map[b]] for a, b, _ in graph.edges]

def pyg_graph_object(graph: nx.DiGraph) -> GeometricData:
    """
    Convert a directed graph to a GeometricData object.

    :param graph: A networkX digraph.
    :return: A GeometricData object.
    """
    vertex_map = get_vertex_map(graph.nodes)
    labels = []
    new_graph = nx.DiGraph()
    edges = encode_edges(graph)
    new_graph.add_edges_from(edges)
    for node in range(0, len(vertex_map)):
        in_degree = new_graph.in_degree(node)
        out_degree = new_graph.out_degree(node)
        labels.append([in_degree, out_degree])

    return GeometricData(edges=edges, labels=labels, num_nodes=len(vertex_map))

def dot_to_pyg_graph_object(graph: pydot.Graph) -> GeometricData:
    """
    Convert a dot file to a pyg graph object.

    :param graph: A pydot Graph.
    :return: A GeometricData object.
    """
    nx_graph = nx.drawing.nx_pydot.from_pydot(graph)
    return pyg_graph_object(nx_graph)


pydot_graphs = pydot.graph_from_dot_file('dataset/data/dbd5ea6f9d712af8fc067d91d44d9fb1952f370c10ca45dc05592623a35fdf85.dot')

print(dot_to_pyg_graph_object(pydot_graphs[0]).to_json())
