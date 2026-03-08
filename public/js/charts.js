// public/js/charts.js - Chart configurations for analytics

// Initialize all charts on a page
function initCharts(chartData) {
  if (document.getElementById('difficultyChart')) {
    initDifficultyChart(chartData.difficulty);
  }
  
  if (document.getElementById('performanceChart')) {
    initPerformanceChart(chartData.performance);
  }
  
  if (document.getElementById('progressChart')) {
    initProgressChart(chartData.progress);
  }
  
  if (document.getElementById('topicChart')) {
    initTopicChart(chartData.topics);
  }
}

// Difficulty distribution chart (doughnut)
function initDifficultyChart(data) {
  const ctx = document.getElementById('difficultyChart').getContext('2d');
  new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['Easy', 'Medium', 'Hard'],
      datasets: [{
        data: [data.easy || 0, data.medium || 0, data.hard || 0],
        backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      cutout: '65%',
      plugins: {
        legend: {
          position: 'bottom',
          labels: {
            usePointStyle: true,
            padding: 20
          }
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = total > 0 ? Math.round((context.raw / total) * 100) : 0;
              return `${context.label}: ${context.raw} (${percentage}%)`;
            }
          }
        }
      }
    }
  });
}

// Performance trend chart (line)
function initPerformanceChart(data) {
  const ctx = document.getElementById('performanceChart').getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: data.labels || [],
      datasets: [
        {
          label: 'Class Average',
          data: data.classAvg || [],
          borderColor: '#8b5cf6',
          backgroundColor: 'rgba(139, 92, 246, 0.1)',
          tension: 0.4,
          fill: true
        },
        {
          label: 'Your Score',
          data: data.studentScores || [],
          borderColor: '#10b981',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          tension: 0.4,
          fill: true
        }
      ]
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          position: 'bottom'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          max: 100,
          title: {
            display: true,
            text: 'Score %'
          }
        }
      }
    }
  });
}

// Student progress chart (line)
function initProgressChart(data) {
  const ctx = document.getElementById('progressChart').getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: data.labels || [],
      datasets: [{
        label: 'Your Progress',
        data: data.scores || [],
        borderColor: '#8b5cf6',
        backgroundColor: 'rgba(139, 92, 246, 0.1)',
        tension: 0.4,
        fill: true
      }]
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          display: false
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          max: 100
        }
      }
    }
  });
}

// Topic performance chart (radar)
function initTopicChart(data) {
  const ctx = document.getElementById('topicChart').getContext('2d');
  new Chart(ctx, {
    type: 'radar',
    data: {
      labels: data.topics || [],
      datasets: [{
        label: 'Your Performance',
        data: data.studentScores || [],
        backgroundColor: 'rgba(139, 92, 246, 0.2)',
        borderColor: '#8b5cf6',
        pointBackgroundColor: '#8b5cf6'
      }, {
        label: 'Class Average',
        data: data.classAvg || [],
        backgroundColor: 'rgba(16, 185, 129, 0.2)',
        borderColor: '#10b981',
        pointBackgroundColor: '#10b981'
      }]
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          position: 'bottom'
        }
      },
      scales: {
        r: {
          beginAtZero: true,
          max: 100
        }
      }
    }
  });
}

// Export chart as image
function exportChart(chartId, filename) {
  const canvas = document.getElementById(chartId);
  if (canvas) {
    const link = document.createElement('a');
    link.download = filename || 'chart.png';
    link.href = canvas.toDataURL('image/png');
    link.click();
  }
}