import torch
import networkx as nx

import os
import json

from torch_geometric import datasets
from torch_geometric import utils as tgutils
from dataclasses import dataclass

from typing import List


def main() -> None:
    """
    Entrypoint for the script.
    """
    training_data = datasets.MalNetTiny(
        root="data",
        split="train",
    )

    test_data = datasets.MalNetTiny(
        root="data",
        split="test",
    )

    generate_data("simgnn/dataset/train", training_data, 8000)
    generate_data("simgnn/dataset/test", test_data, 2000)


@dataclass(frozen=True)
class Sample:
    """
    A sample that maps to the same format as
    seen here https://github.com/benedekrozemberczki/SimGNN.
    """

    graph_1: List[List[int]]
    graph_2: List[List[int]]
    labels_1: List[int]
    labels_2: List[int]
    ged: int

    def to_json(self) -> str:
        """
        Convert a Sample to json.

        :returns: The sample as a json string.
        """
        return json.dumps(
            {
                "graph_1": self.graph_1,
                "graph_2": self.graph_2,
                "labels_1": self.labels_1,
                "labels_2": self.labels_2,
                "ged": self.ged,
            }
        )


def approximate_ged(num_iters: int):
    """
    Approximate the graph edit distance between two graphs.

    :param num_iters: The number of iterations to run the approximation algorithm.

    :returns: A function that takes two graphs.
    """
    def approximate_closure(nx_graph_one: nx.DiGraph, nx_graph_two: nx.DiGraph) -> int:
        idx = 1
        minv = None
        for v in nx.optimize_graph_edit_distance(nx_graph_one, nx_graph_two):
            minv = v
            if idx == num_iters:
                break

            idx += 1

        return int(minv)

    return approximate_closure


def generate_edgelist(nx_graph: nx.DiGraph) -> List[List[int]]:
    """
    Generate the edgelist for the networkX graph.

    :param nx_graph: THe networkX graph to work with.

    :returns: A list of edges of the graph.
    """
    return [[a, b] for a, b in nx_graph.edges()]


def get_labels(nx_graph: nx.DiGraph) -> List[int]:
    """
    Generate the labels for the networkX graph. We assume that
    the graph nodes are indexed by 0.

    :param nx_graph: The networkX graph to work with.

    :returns: A list of labels for each of the nodes in the graph.
    """
    return [nx_graph.degree(node) for node in nx_graph.nodes()]


def generate_data(
    directory: str, data: datasets.MalNetTiny, num_samples: int, a_threshold=1,
) -> None:
    """
    Generate the data given a directory, the data to sample, the number of samples
    to make, and a threshold on how many times we want the optimize_graph_edit_distance
    to sample.

    :param directory: The directory to place the data (which will be indexed starting from 0).
    :param data: The dataset to generate the data from.
    :param num_samples: The number of samples to take.
    :param a_threshold: The threshold of samples to take.
    """
    ged_approximater = approximate_ged(a_threshold)

    if not os.path.exists(directory):
        os.makedirs(directory)

    for idx in range(num_samples):
        with open(f"{directory}/{idx}", "w") as file:
            sample_idx_one = torch.randint(len(data), size=(1,)).item()
            sample_idx_two = torch.randint(len(data), size=(1,)).item()
            t_data_one = data[sample_idx_one]
            t_data_two = data[sample_idx_two]
            nx_data_one = tgutils.to_networkx(t_data_one)
            nx_data_two = tgutils.to_networkx(t_data_two)
            ged = ged_approximater(nx_data_one, nx_data_two)
            sample = Sample(
                graph_1=generate_edgelist(nx_data_one),
                graph_2=generate_edgelist(nx_data_two),
                labels_1=get_labels(nx_data_one),
                labels_2=get_labels(nx_data_two),
                ged=ged,
            )
            file.write(sample.to_json())

        print(f"{directory}: {idx + 1} / {num_samples}")


if __name__ == "__main__":
    main()
